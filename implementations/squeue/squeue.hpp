#pragma once

#include "../lib/comm.hpp"
#include <cstdint>
#include <mpi.h>
#include <vector>

template <typename T> class SQueue {
private:
  struct data_t {
    T data;
    bool marked;
  };

  MPI_Comm _comm;
  MPI_Win _counter_win = MPI_WIN_NULL;
  MPI_Aint *_counter_ptr = nullptr;
  MPI_Win _slot_count_win = MPI_WIN_NULL;
  MPI_Aint *_slot_count_ptr = nullptr;
  MPI_Win _data_win = MPI_WIN_NULL;
  T *_data_ptr = nullptr;
  MPI_Win _timestamp_win = MPI_WIN_NULL;
  int64_t *_timestamp_ptr = nullptr;
  MPI_Info _info = MPI_INFO_NULL;
  MPI_Aint _capacity;
  int _dequeuer_rank;

public:
  SQueue(MPI_Aint capacity, int dequeuer_rank, MPI_Comm comm)
      : _capacity(capacity), _dequeuer_rank(dequeuer_rank), _comm(comm) {
    int self_rank;
    MPI_Comm_rank(comm, &self_rank);
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (self_rank == dequeuer_rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &_counter_ptr, &_counter_win);
      *_counter_ptr = 0;
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &_slot_count_ptr, &_slot_count_win);
      *_slot_count_ptr = capacity;
      MPI_Win_allocate(sizeof(T) * capacity, sizeof(T), this->_info, comm,
                       &_data_ptr, &_data_win);
      MPI_Win_allocate(sizeof(int64_t) * capacity, sizeof(int64_t), this->_info,
                       comm, &_timestamp_ptr, &_timestamp_win);
      for (int i = 0; i < capacity; ++i) {
        _timestamp_ptr[i] = -1;
        _data_ptr[i].marked = false;
      }
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &_counter_ptr,
                       &_counter_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &_slot_count_ptr,
                       &_slot_count_win);
      MPI_Win_allocate(0, sizeof(T), this->_info, comm, &_data_ptr, &_data_win);
      MPI_Win_allocate(0, sizeof(int64_t), this->_info, comm, &_timestamp_ptr,
                       &_timestamp_win);
    }

    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_slot_count_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_timestamp_win);
    MPI_Win_flush_all(this->_counter_win);
    MPI_Win_flush_all(this->_slot_count_win);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_timestamp_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_counter_win);
    MPI_Win_flush_all(this->_slot_count_win);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_timestamp_win);
  }

  SQueue(const SQueue &) = delete;
  SQueue &operator=(const SQueue &) = delete;

  SQueue(SQueue &&other) noexcept
      : _comm(other._comm), _counter_win(other._counter_win),
        _counter_ptr(other._counter_ptr),
        _slot_count_win(other._slot_count_win),
        _slot_count_ptr(other._slot_count_ptr), _data_win(other._data_win),
        _data_ptr(other._data_ptr), _timestamp_win(other._timestamp_win),
        _timestamp_ptr(other._timestamp_ptr), _info(other._info),
        _capacity(other._capacity), _dequeuer_rank(other._dequeuer_rank) {

    other._counter_win = MPI_WIN_NULL;
    other._counter_ptr = nullptr;
    other._slot_count_win = MPI_WIN_NULL;
    other._slot_count_ptr = nullptr;
    other._data_win = MPI_WIN_NULL;
    other._data_ptr = nullptr;
    other._info = MPI_INFO_NULL;
    other._capacity = 0;
    other._dequeuer_rank = -1;
  }

  ~SQueue() {
    if (_data_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_data_win);
      MPI_Win_free(&_data_win);
      _data_win = MPI_WIN_NULL;
      _data_ptr = nullptr;
    }

    if (_timestamp_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_timestamp_win);
      MPI_Win_free(&_timestamp_win);
      _timestamp_win = MPI_WIN_NULL;
      _timestamp_ptr = nullptr;
    }

    if (_slot_count_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_slot_count_win);
      MPI_Win_free(&_slot_count_win);
      _slot_count_win = MPI_WIN_NULL;
      _slot_count_ptr = nullptr;
    }

    if (_counter_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_counter_win);
      MPI_Win_free(&_counter_win);
      _counter_win = MPI_WIN_NULL;
      _counter_ptr = nullptr;
    }

    if (_info != MPI_INFO_NULL) {
      MPI_Info_free(&_info);
      _info = MPI_INFO_NULL;
    }
  }

  bool enqueue(T &data) {
    MPI_Aint slot_count;
    fetch_and_add_sync(&slot_count, -1, 0, this->_dequeuer_rank,
                       this->_slot_count_win);
    if (slot_count < 0) {
      fetch_and_add_sync(&slot_count, 1, 0, this->_dequeuer_rank,
                         this->_slot_count_win);
      return false;
    }
    while (true) {
      MPI_Aint timestamp;
      fetch_and_add_sync(&timestamp, 1, 0, this->_dequeuer_rank,
                         this->_counter_win);
      MPI_Aint old_timestamp;
      aread_sync(&old_timestamp, timestamp % this->_capacity,
                 this->_dequeuer_rank, this->_timestamp_win);
      if (old_timestamp != -1) {
        continue;
      }
      MPI_Aint new_timestamp;
      compare_and_swap_sync(&old_timestamp, &timestamp, &new_timestamp,
                            timestamp % this->_capacity, this->_dequeuer_rank,
                            this->_timestamp_win);
      if (new_timestamp != -1) {
        continue;
      }
      const data_t entry = {data, true};
      awrite_async(&entry, timestamp % this->_capacity, this->_dequeuer_rank,
                   this->_data_win);
      return true;
    }
  }

  bool dequeue(std::vector<T> &output) {
  }
};
