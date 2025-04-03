#pragma once

#include "../comm.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <queue>
#include <vector>

template <typename T> class SlotEnqueuerV2 {
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

  public:
    Spsc(MPI_Aint capacity, MPI_Aint self_rank, MPI_Aint dequeuer_rank,
         MPI_Comm comm)
        : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
          _capacity{capacity}, _first_buf{0}, _last_buf{0} {
      MPI_Info info;
      MPI_Info_create(&info);
      MPI_Info_set(info, "same_disp_unit", "true");

      MPI_Win_allocate(capacity * sizeof(data_t), sizeof(data_t), info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_first_ptr, &this->_first_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_last_ptr, &this->_last_win);

      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      *this->_first_ptr = 0;
      *this->_last_ptr = 0;
      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Barrier(comm);

      MPI_Win_lock_all(0, _first_win);
      MPI_Win_lock_all(0, _last_win);
      MPI_Win_lock_all(0, _data_win);
    }

    ~Spsc() {
      MPI_Win_unlock_all(_first_win);
      MPI_Win_unlock_all(_last_win);
      MPI_Win_unlock_all(_data_win);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
    }

    bool enqueue(const data_t &data) {
      MPI_Aint new_last = this->_last_buf + 1;

      if (new_last - this->_first_buf > this->_capacity) {
        aread_sync(&this->_first_buf, 0, this->_self_rank, this->_first_win);
        if (new_last - this->_first_buf > this->_capacity) {
          return false;
        }
      }

      awrite_sync(&data, this->_last_buf % this->_capacity, this->_self_rank,
                  this->_data_win);
      awrite_sync(&new_last, 0, this->_self_rank, this->_last_win);
      this->_last_buf = new_last;

      return true;
    }

    bool enqueue(const std::vector<data_t> &data) {
      MPI_Aint new_last = this->_last_buf + data.size();

      if (new_last - this->_first_buf > this->_capacity) {
        aread_sync(&this->_first_buf, 0, this->_self_rank, this->_first_win);
        if (new_last - this->_first_buf > this->_capacity) {
          return false;
        }
      }

      if (this->_capacity - this->_last_buf % this->_capacity >= data.size()) {
        batch_awrite_sync(data.data(), data.size(),
                          this->_last_buf % this->_capacity, this->_self_rank,
                          this->_data_win);
      } else {
        batch_awrite_async(data.data(),
                           this->_capacity - this->_last_buf % this->_capacity,
                           this->_last_buf % this->_capacity, this->_self_rank,
                           this->_data_win);
        batch_awrite_async(
            data.data() + this->_capacity - this->_last_buf % this->_capacity,
            data.size() - this->_capacity + this->_last_buf % this->_capacity,
            0, this->_self_rank, this->_data_win);
        flush(this->_self_rank, this->_data_win);
      }

      awrite_sync(&new_last, 0, this->_self_rank, this->_last_win);
      this->_last_buf = new_last;

      return true;
    }

    bool read_front(timestamp_t *output_timestamp) {
      if (this->_first_buf >= this->_last_buf) {
        return false;
      }
      aread_sync(&this->_first_buf, 0, this->_self_rank, this->_first_win);
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

    timestamp_t old_timestamp;
    aread_sync(&old_timestamp, this->_enqueuer_order, this->_dequeuer_rank,
               this->_min_timestamp_win);
    timestamp_t new_timestamp;
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
  SlotEnqueuerV2(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
                 MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _enqueuer_order{self_rank > dequeuer_rank ? self_rank - 1 : self_rank},
        _spsc{capacity, self_rank, dequeuer_rank, comm} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(0, sizeof(timestamp_t), info, comm, &this->_counter_ptr,
                     &this->_counter_win);

    MPI_Win_allocate(0, sizeof(timestamp_t), info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);

    MPI_Barrier(comm);

    MPI_Win_lock_all(0, _counter_win);
    MPI_Win_lock_all(0, _min_timestamp_win);
  }

  SlotEnqueuerV2(const SlotEnqueuerV2 &) = delete;
  SlotEnqueuerV2 &operator=(const SlotEnqueuerV2 &) = delete;

  ~SlotEnqueuerV2() {
    MPI_Win_unlock_all(_counter_win);
    MPI_Win_unlock_all(_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
    MPI_Win_free(&this->_min_timestamp_win);
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

template <typename T> class SlotDequeuerV2 {
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

  struct slot_t {
    MPI_Aint index;
    timestamp_t timestamp;
    friend bool operator<(const slot_t &a, const slot_t &b) {
      return a.timestamp < b.timestamp;
    }
  };
  typedef std::priority_queue<slot_t, std::vector<slot_t>>
      priority_slot_queue_t;
  priority_slot_queue_t _first_scan;
  priority_slot_queue_t _second_scan;

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

  public:
    Spsc(MPI_Aint capacity, MPI_Aint self_rank, MPI_Comm comm)
        : _self_rank{self_rank}, _capacity{capacity} {
      int size;
      MPI_Comm_size(comm, &size);
      _first_buf = std::vector<MPI_Aint>(size);
      _last_buf = std::vector<MPI_Aint>(size);

      MPI_Info info;
      MPI_Info_create(&info);
      MPI_Info_set(info, "same_disp_unit", "true");

      MPI_Win_allocate(0, sizeof(data_t), info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_first_ptr,
                       &this->_first_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_last_ptr,
                       &this->_last_win);
      MPI_Barrier(comm);

      MPI_Win_lock_all(0, _first_win);
      MPI_Win_lock_all(0, _last_win);
      MPI_Win_lock_all(0, _data_win);
    }

    ~Spsc() {
      MPI_Win_unlock_all(_first_win);
      MPI_Win_unlock_all(_last_win);
      MPI_Win_unlock_all(_data_win);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
    }

    bool dequeue(data_t *output, int enqueuer_rank) {
      MPI_Aint new_first = this->_first_buf[enqueuer_rank] + 1;
      if (new_first > this->_last_buf[enqueuer_rank]) {
        aread_sync(&this->_last_buf[enqueuer_rank], 0, enqueuer_rank,
                   this->_last_win);
        if (new_first > this->_last_buf[enqueuer_rank]) {
          return false;
        }
      }

      aread_sync(output, this->_first_buf[enqueuer_rank] % this->_capacity,
                 enqueuer_rank, this->_data_win);
      awrite_sync(&new_first, 0, enqueuer_rank, this->_first_win);
      this->_first_buf[enqueuer_rank] = new_first;

      return true;
    }

    bool read_front(timestamp_t *output_timestamp, int enqueuer_rank) {
      if (this->_first_buf[enqueuer_rank] >= this->_last_buf[enqueuer_rank]) {
        aread_sync(&this->_last_buf[enqueuer_rank], 0, enqueuer_rank,
                   this->_last_win);
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

    MPI_Aint rank = this->_readMinimumRankFromScans();
    if (rank != MAX_TIMESTAMP) {
      return rank;
    }
    batch_aread_sync(this->_min_timestamp_buf, this->_number_of_enqueuers, 0,
                     this->_self_rank, this->_min_timestamp_win);
    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      if (_min_timestamp_buf[i] != MAX_TIMESTAMP) {
        this->_first_scan.push({(MPI_Aint)i, _min_timestamp_buf[i]});
      }
    }
    if (this->_first_scan.size() == 0) {
      return DUMMY_RANK;
    }
    batch_aread_sync(this->_min_timestamp_buf, this->_number_of_enqueuers, 0,
                     this->_self_rank, this->_min_timestamp_win);
    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      if (_min_timestamp_buf[i] != MAX_TIMESTAMP) {
        this->_second_scan.push({(MPI_Aint)i, _min_timestamp_buf[i]});
      }
    }
    return this->_readMinimumRankFromScans();
  }

  MPI_Aint _readMinimumRankFromScans() {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    if (this->_first_scan.size() == 0) {
      this->_second_scan = priority_slot_queue_t();
      return DUMMY_RANK;
    }
    slot_t first_top = this->_first_scan.top();
    slot_t second_top = this->_second_scan.top();
    if (first_top.index == second_top.index) {
      this->_first_scan.pop();
      this->_second_scan.pop();
      return first_top.index >= this->_self_rank ? first_top.index + 1
                                                 : first_top.index;
    }
    if (second_top.timestamp < first_top.timestamp) {
      this->_second_scan.pop();
      return second_top.index >= this->_self_rank ? second_top.index + 1
                                                  : second_top.index;
    }
    this->_first_scan.pop();
    return first_top.index >= this->_self_rank ? first_top.index + 1
                                               : first_top.index;
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
    } else {
      this->_second_scan.push({enqueuer_order, new_timestamp});
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
  SlotDequeuerV2(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
                 MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _spsc{capacity, self_rank, comm} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(sizeof(timestamp_t), sizeof(timestamp_t), info, comm,
                     &this->_counter_ptr, &this->_counter_win);
    MPI_Win_lock_all(0, this->_counter_win);
    *this->_counter_ptr = 0;
    MPI_Win_unlock_all(this->_counter_win);

    int size;
    MPI_Comm_size(comm, &size);
    this->_number_of_enqueuers = size - 1;
    MPI_Win_allocate(this->_number_of_enqueuers * sizeof(timestamp_t),
                     sizeof(timestamp_t), info, comm, &this->_min_timestamp_ptr,
                     &this->_min_timestamp_win);
    MPI_Win_lock_all(0, this->_min_timestamp_win);
    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      this->_min_timestamp_ptr[i] = MAX_TIMESTAMP;
    }
    MPI_Win_unlock_all(this->_min_timestamp_win);
    this->_min_timestamp_buf = new timestamp_t[this->_number_of_enqueuers];

    MPI_Barrier(comm);
    MPI_Win_lock_all(0, _counter_win);
    MPI_Win_lock_all(0, _min_timestamp_win);
  }

  SlotDequeuerV2(const SlotDequeuerV2 &) = delete;
  SlotDequeuerV2 &operator=(const SlotDequeuerV2 &) = delete;
  ~SlotDequeuerV2() {
    MPI_Win_unlock_all(_counter_win);
    MPI_Win_unlock_all(_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
    MPI_Win_free(&this->_min_timestamp_win);
    delete[] this->_min_timestamp_buf;
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
