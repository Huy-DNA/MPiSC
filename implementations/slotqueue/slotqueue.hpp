#pragma once

#include "../comm.hpp"
#include "../utils/distributed-counters/faa.hpp"
#include "../utils/spsc.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <vector>

template <typename T> class SlotEnqueuer {
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

  FaaCounter _counter;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  MPI_Info _info;

  SpscEnqueuer<data_t> _spsc;

  bool _refreshEnqueue(timestamp_t ts) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    data_t front;
    // avoid possibily redundant remote read below
    timestamp_t new_timestamp;
    if (!this->_spsc.read_front(&front)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
    }
    if (new_timestamp != ts) {
      return true;
    }

    timestamp_t old_timestamp;
    fetch_and_add_sync(&old_timestamp, 0, this->_enqueuer_order,
                       this->_dequeuer_rank, this->_min_timestamp_win);
    if (!this->_spsc.read_front(&front)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
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
  SlotEnqueuer(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
               MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _enqueuer_order{self_rank > dequeuer_rank ? self_rank - 1 : self_rank},
        _spsc{capacity, self_rank, dequeuer_rank, comm},
        _counter{dequeuer_rank, dequeuer_rank, comm} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(0, sizeof(timestamp_t), this->_info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _min_timestamp_win);

    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_min_timestamp_win);
  }

  SlotEnqueuer(const SlotEnqueuer &) = delete;
  SlotEnqueuer &operator=(const SlotEnqueuer &) = delete;

  ~SlotEnqueuer() {
    MPI_Win_unlock_all(_min_timestamp_win);
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Info_free(&this->_info);
  }

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    timestamp_t counter = this->_counter.get_and_increment();
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

    timestamp_t counter = this->_counter.get_and_increment();
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

template <typename T> class SlotDequeuer {
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

  FaaCounter _counter;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;
  timestamp_t *_min_timestamp_buf;
  MPI_Info _info;

  SpscDequeuer<data_t> _spsc;

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
    for (int i = 0; i < order; ++i) {
      aread_async(&this->_min_timestamp_buf[i], i, this->_self_rank,
                  this->_min_timestamp_win);
    }
    flush(this->_self_rank, this->_min_timestamp_win);
    for (int i = 0; i < order; ++i) {
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
    fetch_and_add_sync(&old_timestamp, 0, enqueuer_order, this->_self_rank,
                       this->_min_timestamp_win);
    data_t front;
    timestamp_t new_timestamp;
    if (!this->_spsc.read_front(&front, rank)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
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
  SlotDequeuer(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
               MPI_Comm comm, MPI_Aint batch_size = 10)
      : _comm{comm}, _self_rank{self_rank},
        _spsc{capacity, self_rank, comm, batch_size},
        _counter{dequeuer_rank, dequeuer_rank, comm} {
    int size;
    MPI_Comm_size(comm, &size);
    this->_number_of_enqueuers = size - 1;

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(this->_number_of_enqueuers * sizeof(timestamp_t),
                     sizeof(timestamp_t), this->_info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_min_timestamp_win);

    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      this->_min_timestamp_ptr[i] = MAX_TIMESTAMP;
    }
    this->_min_timestamp_buf = new timestamp_t[this->_number_of_enqueuers];

    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_min_timestamp_win);
  }

  SlotDequeuer(const SlotDequeuer &) = delete;
  SlotDequeuer &operator=(const SlotDequeuer &) = delete;
  ~SlotDequeuer() {
    MPI_Win_unlock_all(_min_timestamp_win);
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
