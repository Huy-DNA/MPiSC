#pragma once

#include "../lib/comm.hpp"
#include "../lib/distributed-counters/cs_faa.hpp"
#include "../lib/spsc/bounded_spsc.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <vector>

template <typename T> class SlotNodeQueue {
private:
  typedef uint64_t timestamp_t;
  constexpr static timestamp_t MAX_TIMESTAMP = ~((uint64_t)0);
  constexpr static MPI_Aint DUMMY_RANK = ~((MPI_Aint)0);

  struct data_t {
    T data;
    uint64_t timestamp;
  };

  MPI_Comm _comm;
  MPI_Aint _size;
  int _self_rank;
  const MPI_Aint _dequeuer_rank;

  CsFaaCounter _counter;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;
  timestamp_t *_min_timestamp_buf;

  MPI_Info _info;

  Spsc<data_t> _spsc;

private:
  bool _refreshEnqueue(timestamp_t ts) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    data_t front;
    // avoid possibily redundant remote read below
    timestamp_t new_timestamp;
    if (!this->_spsc.e_read_front(&front)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
    }
    if (new_timestamp != ts) {
      return true;
    }

    timestamp_t old_timestamp;
    fetch_and_add_sync(&old_timestamp, 0, this->_self_rank,
                       this->_dequeuer_rank, this->_min_timestamp_win);
    if (!this->_spsc.e_read_front(&front)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
    }
    if (new_timestamp != ts) {
      return true;
    }
    timestamp_t result;
    compare_and_swap_sync(&old_timestamp, &new_timestamp, &result,
                          this->_self_rank, this->_dequeuer_rank,
                          this->_min_timestamp_win);
    return result == old_timestamp;
  }

private:
  MPI_Aint _readMinimumRank() {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    MPI_Aint rank = DUMMY_RANK;
    timestamp_t min_timestamp = MAX_TIMESTAMP;

    for (int i = 0; i < this->_size; ++i) {
      aread_sync(&this->_min_timestamp_buf[i], i, this->_self_rank,
                 this->_min_timestamp_win);
    }
    for (int i = 0; i < this->_size; ++i) {
      timestamp_t timestamp = this->_min_timestamp_buf[i];
      if (timestamp < min_timestamp) {
        rank = i;
        min_timestamp = timestamp;
      }
    }
    if (rank == DUMMY_RANK) {
      return DUMMY_RANK;
    }
    for (int i = 0; i < rank; ++i) {
      aread_sync(&this->_min_timestamp_buf[i], i, this->_self_rank,
                 this->_min_timestamp_win);
    }
    for (int i = 0; i < rank; ++i) {
      timestamp_t timestamp = this->_min_timestamp_buf[i];
      if (timestamp < min_timestamp) {
        rank = i;
        min_timestamp = timestamp;
      }
    }
    return rank;
  }

  bool _refreshDequeue(MPI_Aint rank) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    timestamp_t old_timestamp;
    fetch_and_add_sync(&old_timestamp, 0, rank, this->_self_rank,
                       this->_min_timestamp_win);
    data_t front;
    timestamp_t new_timestamp;
    if (!this->_spsc.d_read_front(&front, rank)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
    }
    timestamp_t result;
    compare_and_swap_sync(&old_timestamp, &new_timestamp, &result, rank,
                          this->_self_rank, this->_min_timestamp_win);
    return result == old_timestamp;
  }

public:
  SlotNodeQueue(MPI_Aint capacity_per_node, MPI_Aint dequeuer_rank,
                MPI_Comm comm)
      : _comm{comm}, _dequeuer_rank{dequeuer_rank},
        _spsc{capacity_per_node, dequeuer_rank, comm},
        _counter{dequeuer_rank, comm} {
    int size;
    MPI_Comm_rank(comm, &this->_self_rank);
    MPI_Comm_size(comm, &size);
    this->_size = size;

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (this->_self_rank == this->_dequeuer_rank) {
      MPI_Win_allocate(this->_size * sizeof(timestamp_t), sizeof(timestamp_t),
                       this->_info, comm, &this->_min_timestamp_ptr,
                       &this->_min_timestamp_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_min_timestamp_win);

      for (int i = 0; i < this->_size; ++i) {
        this->_min_timestamp_ptr[i] = MAX_TIMESTAMP;
      }
      this->_min_timestamp_buf = new timestamp_t[this->_size];
    } else {
      MPI_Win_allocate(0, sizeof(timestamp_t), this->_info, comm,
                       &this->_min_timestamp_ptr, &this->_min_timestamp_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _min_timestamp_win);
    }
    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_min_timestamp_win);
  }

  SlotNodeQueue(const SlotNodeQueue &) = delete;
  SlotNodeQueue &operator=(const SlotNodeQueue &) = delete;

  SlotNodeQueue(SlotNodeQueue &&other) noexcept
      : _comm(other._comm), _size(other._size), _self_rank(other._self_rank),
        _dequeuer_rank(other._dequeuer_rank),
        _counter(std::move(other._counter)),
        _min_timestamp_win(other._min_timestamp_win),
        _min_timestamp_ptr(other._min_timestamp_ptr),
        _min_timestamp_buf(other._min_timestamp_buf), _info(other._info),
        _spsc(std::move(other._spsc)) {
    other._comm = MPI_COMM_NULL;
    other._min_timestamp_win = MPI_WIN_NULL;
    other._min_timestamp_ptr = nullptr;
    other._min_timestamp_buf = nullptr;
    other._info = MPI_INFO_NULL;
  }

  ~SlotNodeQueue() {
    if (this->_min_timestamp_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_min_timestamp_win);
      MPI_Win_free(&this->_min_timestamp_win);
    }
    if (this->_info != MPI_INFO_NULL) {
      MPI_Info_free(&this->_info);
    }
    if (this->_self_rank == this->_dequeuer_rank) {
      delete[] this->_min_timestamp_buf;
    }
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
