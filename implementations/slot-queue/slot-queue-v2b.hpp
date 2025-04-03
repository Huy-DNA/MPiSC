#pragma once

#include "../comm.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <vector>

template <typename T> class SlotEnqueuerV2b {
private:
  typedef uint64_t timestamp_t;
  constexpr static timestamp_t MAX_TIMESTAMP = ~((uint64_t)0);

  struct data_t {
    T data;
    uint64_t timestamp;
  };

  MPI_Comm _comm;
  const MPI_Aint _self_rank;
  const MPI_Aint _enqueuer_order;
  const MPI_Aint _dequeuer_rank;

  MPI_Win _counter_win;
  timestamp_t *_counter_ptr;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  MPI_Info _info;

  class Spsc {
    const MPI_Aint _self_rank;
    const MPI_Aint _dequeuer_rank;

    const MPI_Aint _capacity;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;
    MPI_Aint _first_buf;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;
    MPI_Aint _last_buf;
    MPI_Info _info;

  public:
    Spsc(MPI_Aint capacity, MPI_Aint self_rank, MPI_Aint dequeuer_rank,
         MPI_Comm comm)
        : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
          _capacity{capacity}, _first_buf{0}, _last_buf{0} {
      MPI_Info_create(&this->_info);
      MPI_Info_set(this->_info, "same_disp_unit", "true");
      MPI_Info_set(this->_info, "accumulate_ordering", "none");

      MPI_Win_allocate(capacity * sizeof(data_t), sizeof(data_t), this->_info,
                       comm, &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_first_ptr, &this->_first_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_last_ptr,
                       &this->_last_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _first_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _last_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_win);

      MPI_Win_flush_all(this->_data_win);
      MPI_Win_flush_all(this->_first_win);
      MPI_Win_flush_all(this->_last_win);
      MPI_Barrier(comm);
      MPI_Win_flush_all(this->_data_win);
      MPI_Win_flush_all(this->_first_win);
      MPI_Win_flush_all(this->_last_win);
    }

    ~Spsc() {
      MPI_Win_unlock_all(_first_win);
      MPI_Win_unlock_all(_last_win);
      MPI_Win_unlock_all(_data_win);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
      MPI_Info_free(&this->_info);
    }

    bool enqueue(const data_t &data) {
      MPI_Aint new_last = this->_last_buf + 1;

      if (new_last - this->_first_buf > this->_capacity) {
        aread_sync(&this->_first_buf, this->_self_rank, this->_dequeuer_rank,
                   this->_first_win);
        if (new_last - this->_first_buf > this->_capacity) {
          return false;
        }
      }

      awrite_sync(&data, this->_last_buf % this->_capacity, this->_self_rank,
                  this->_data_win);
      awrite_sync(&new_last, this->_self_rank, this->_dequeuer_rank,
                  this->_last_win);
      this->_last_buf = new_last;

      return true;
    }

    bool enqueue(const std::vector<data_t> &data) {
      MPI_Aint new_last = this->_last_buf + data.size();

      if (new_last - this->_first_buf > this->_capacity) {
        aread_sync(&this->_first_buf, this->_self_rank, this->_dequeuer_rank,
                   this->_first_win);
        if (new_last - this->_first_buf > this->_capacity) {
          return false;
        }
      }

      const uint64_t size = data.size();
      for (int i = 0; i < size; ++i) {
        const uint64_t disp = (this->_last_buf + i) % this->_capacity;
        awrite_async(data.data() + i, disp, this->_self_rank,
                     this->_data_win);
      }
      flush(this->_self_rank, this->_data_win);

      awrite_sync(&new_last, this->_self_rank, this->_dequeuer_rank,
                  this->_last_win);
      this->_last_buf = new_last;

      return true;
    }

    bool read_front(timestamp_t *output_timestamp) {
      if (this->_first_buf >= this->_last_buf) {
        return false;
      }
      aread_sync(&this->_first_buf, this->_self_rank, this->_dequeuer_rank,
                 this->_first_win);
      if (this->_first_buf >= this->_last_buf) {
        return false;
      }

      data_t data;
      aread_sync(&data, this->_first_buf % this->_capacity, this->_self_rank,
                 this->_data_win);

      *output_timestamp = data.timestamp;
      return true;
    }
  } _spsc;

  bool _refreshEnqueue(timestamp_t ts) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    // avoid possibily redundant remote read below
    timestamp_t new_timestamp;
    if (!this->_spsc.read_front(&new_timestamp)) {
      new_timestamp = MAX_TIMESTAMP;
    }
    if (new_timestamp != ts) {
      return true;
    }

    timestamp_t old_timestamp;
    aread_sync(&old_timestamp, this->_enqueuer_order, this->_dequeuer_rank,
               this->_min_timestamp_win);
    if (!this->_spsc.read_front(&new_timestamp)) {
      new_timestamp = MAX_TIMESTAMP;
    }
    if (new_timestamp != ts) {
      return true;
    }
    timestamp_t result;
    compare_and_swap_sync(&old_timestamp, &new_timestamp, &result,
                          this->_enqueuer_order, this->_dequeuer_rank,
                          this->_min_timestamp_win);
    return result == old_timestamp;
  }

public:
  SlotEnqueuerV2b(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
                  MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _enqueuer_order{self_rank > dequeuer_rank ? self_rank - 1 : self_rank},
        _spsc{capacity, self_rank, dequeuer_rank, comm} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(0, sizeof(timestamp_t), this->_info, comm,
                     &this->_counter_ptr, &this->_counter_win);
    MPI_Win_allocate(0, sizeof(timestamp_t), this->_info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _min_timestamp_win);

    MPI_Win_flush_all(this->_counter_win);
    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_counter_win);
    MPI_Win_flush_all(this->_min_timestamp_win);
  }

  SlotEnqueuerV2b(const SlotEnqueuerV2b &) = delete;
  SlotEnqueuerV2b &operator=(const SlotEnqueuerV2b &) = delete;

  ~SlotEnqueuerV2b() {
    MPI_Win_unlock_all(_counter_win);
    MPI_Win_unlock_all(_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Info_free(&this->_info);
  }

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    timestamp_t counter;
    fetch_and_add_sync(&counter, 1, 0, this->_dequeuer_rank,
                       this->_counter_win);
    data_t value{data, counter};
    bool res = this->_spsc.enqueue(value);
    if (!res) {
      return false;
    }
    if (!this->_refreshEnqueue(counter)) {
      this->_refreshEnqueue(counter);
    }
    return res;
  }

  bool enqueue(const std::vector<T> &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    if (data.size() == 0) {
      return true;
    }

    timestamp_t counter;
    fetch_and_add_sync(&counter, 1, 0, this->_dequeuer_rank,
                       this->_counter_win);
    std::vector<data_t> timestamped_data;
    for (const T &datum : data) {
      timestamped_data.push_back(data_t{datum, counter});
    }
    bool res = this->_spsc.enqueue(timestamped_data);
    if (!res) {
      return false;
    }
    if (!this->_refreshEnqueue(counter)) {
      this->_refreshEnqueue(counter);
    }
    return res;
  }
};

template <typename T> class SlotDequeuerV2b {
private:
  typedef uint64_t timestamp_t;
  constexpr static timestamp_t MAX_TIMESTAMP = ~((uint64_t)0);
  constexpr static MPI_Aint DUMMY_RANK = ~((MPI_Aint)0);

  struct data_t {
    T data;
    uint64_t timestamp;
  };

  const MPI_Aint _self_rank;
  MPI_Comm _comm;
  MPI_Aint _number_of_enqueuers;

  MPI_Win _counter_win;
  timestamp_t *_counter_ptr;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;
  timestamp_t *_min_timestamp_buf;
  MPI_Info _info;

  class Spsc {
    const MPI_Aint _self_rank;

    const MPI_Aint _capacity;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;
    std::vector<MPI_Aint> _first_buf;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;
    std::vector<MPI_Aint> _last_buf;
    MPI_Info _info;

  public:
    Spsc(MPI_Aint capacity, MPI_Aint self_rank, MPI_Comm comm)
        : _self_rank{self_rank}, _capacity{capacity} {
      int size;
      MPI_Comm_size(comm, &size);
      _first_buf = std::vector<MPI_Aint>(size);
      _last_buf = std::vector<MPI_Aint>(size);

      MPI_Info_create(&this->_info);
      MPI_Info_set(this->_info, "same_disp_unit", "true");
      MPI_Info_set(this->_info, "accumulate_ordering", "none");

      MPI_Win_allocate(0, sizeof(data_t), this->_info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(size * sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info,
                       comm, &this->_first_ptr, &this->_first_win);
      MPI_Win_allocate(size * sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info,
                       comm, &this->_last_ptr, &this->_last_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _first_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _last_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_win);
      for (int i = 0; i < size; ++i) {
        this->_first_ptr[i] = 0;
        this->_last_ptr[i] = 0;
      }

      MPI_Win_flush_all(this->_data_win);
      MPI_Win_flush_all(this->_first_win);
      MPI_Win_flush_all(this->_last_win);
      MPI_Barrier(comm);
      MPI_Win_flush_all(this->_data_win);
      MPI_Win_flush_all(this->_first_win);
      MPI_Win_flush_all(this->_last_win);
    }

    ~Spsc() {
      MPI_Win_unlock_all(_first_win);
      MPI_Win_unlock_all(_last_win);
      MPI_Win_unlock_all(_data_win);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
      MPI_Info_free(&this->_info);
    }

    bool dequeue(data_t *output, int enqueuer_rank) {
      MPI_Aint new_first = this->_first_buf[enqueuer_rank] + 1;
      if (new_first > this->_last_buf[enqueuer_rank]) {
        aread_sync(&this->_last_buf[enqueuer_rank], enqueuer_rank,
                   this->_self_rank, this->_last_win);
        if (new_first > this->_last_buf[enqueuer_rank]) {
          return false;
        }
      }

      aread_sync(output, this->_first_buf[enqueuer_rank] % this->_capacity,
                 enqueuer_rank, this->_data_win);
      awrite_sync(&new_first, enqueuer_rank, this->_self_rank,
                  this->_first_win);
      this->_first_buf[enqueuer_rank] = new_first;

      return true;
    }

    bool read_front(timestamp_t *output_timestamp, int enqueuer_rank) {
      if (this->_first_buf[enqueuer_rank] >= this->_last_buf[enqueuer_rank]) {
        aread_sync(&this->_last_buf[enqueuer_rank], enqueuer_rank,
                   this->_self_rank, this->_last_win);
        if (this->_first_buf[enqueuer_rank] >= this->_last_buf[enqueuer_rank]) {
          return false;
        }
      }

      data_t data;
      aread_sync(&data, this->_first_buf[enqueuer_rank] % this->_capacity,
                 enqueuer_rank, this->_data_win);
      *output_timestamp = data.timestamp;
      return true;
    }
  } _spsc;

  MPI_Aint _readMinimumRank() {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    MPI_Aint order = DUMMY_RANK;
    timestamp_t min_timestamp = MAX_TIMESTAMP;

    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      aread_async(&this->_min_timestamp_buf[i], i, this->_self_rank,
                  this->_min_timestamp_win);
    }
    flush(this->_self_rank, this->_min_timestamp_win);
    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      timestamp_t timestamp = this->_min_timestamp_buf[i];
      if (timestamp < min_timestamp) {
        order = i;
        min_timestamp = timestamp;
      }
    }
    if (order == DUMMY_RANK) {
      return DUMMY_RANK;
    }
    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      aread_async(&this->_min_timestamp_buf[i], i, this->_self_rank,
                  this->_min_timestamp_win);
    }
    flush(this->_self_rank, this->_min_timestamp_win);
    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      timestamp_t timestamp = this->_min_timestamp_buf[i];
      if (timestamp < min_timestamp) {
        order = i;
        min_timestamp = timestamp;
      }
    }
    return order >= this->_self_rank ? order + 1 : order;
  }

  bool _refreshDequeue(MPI_Aint rank) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    MPI_Aint enqueuer_order = this->_get_enqueuer_order(rank);
    timestamp_t old_timestamp;
    aread_sync(&old_timestamp, enqueuer_order, this->_self_rank,
               this->_min_timestamp_win);
    timestamp_t new_timestamp;
    if (!this->_spsc.read_front(&new_timestamp, rank)) {
      new_timestamp = MAX_TIMESTAMP;
    }
    timestamp_t result;
    compare_and_swap_sync(&old_timestamp, &new_timestamp, &result,
                          enqueuer_order, this->_self_rank,
                          this->_min_timestamp_win);
    return result == old_timestamp;
  }

  int _get_enqueuer_order(MPI_Aint rank) const {
    return rank > this->_self_rank ? rank - 1 : rank;
  }

public:
  SlotDequeuerV2b(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
                  MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _spsc{capacity, self_rank, comm} {
    int size;
    MPI_Comm_size(comm, &size);
    this->_number_of_enqueuers = size - 1;

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(sizeof(timestamp_t), sizeof(timestamp_t), this->_info,
                     comm, &this->_counter_ptr, &this->_counter_win);
    MPI_Win_allocate(this->_number_of_enqueuers * sizeof(timestamp_t),
                     sizeof(timestamp_t), this->_info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_min_timestamp_win);
    *this->_counter_ptr = 0;

    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      this->_min_timestamp_ptr[i] = MAX_TIMESTAMP;
    }
    this->_min_timestamp_buf = new timestamp_t[this->_number_of_enqueuers];

    MPI_Win_flush_all(this->_counter_win);
    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_counter_win);
    MPI_Win_flush_all(this->_min_timestamp_win);
  }

  SlotDequeuerV2b(const SlotDequeuerV2b &) = delete;
  SlotDequeuerV2b &operator=(const SlotDequeuerV2b &) = delete;
  ~SlotDequeuerV2b() {
    MPI_Win_unlock_all(_counter_win);
    MPI_Win_unlock_all(_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
    MPI_Win_free(&this->_min_timestamp_win);
    delete[] this->_min_timestamp_buf;
    MPI_Info_free(&this->_info);
  }

  bool dequeue(T *output) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    MPI_Aint rank = this->_readMinimumRank();
    if (rank == DUMMY_RANK) {
      return false;
    }
    data_t output_data;
    bool res = this->_spsc.dequeue(&output_data, rank);
    if (!res) {
      return false;
    }
    *output = output_data.data;
    if (!this->_refreshDequeue(rank)) {
      this->_refreshDequeue(rank);
    }
    return true;
  }
};
