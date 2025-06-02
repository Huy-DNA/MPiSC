#pragma once

#include "../lib/comm.hpp"
#include <cstdint>
#include <cstdlib>
#include <mpi.h>
#include <vector>

template <typename T> class AMQueue {
private:
  MPI_Comm _comm;
  int _self_rank;
  const MPI_Aint _dequeuer_rank;
  const MPI_Aint _capacity;

  MPI_Win _data_0_win = MPI_WIN_NULL;
  T *_data_0_ptr = nullptr;

  MPI_Win _data_1_win = MPI_WIN_NULL;
  T *_data_1_ptr = nullptr;

  MPI_Win _queue_num_win = MPI_WIN_NULL;
  bool *_queue_num_ptr = nullptr;

  MPI_Win _writer_count_0_win = MPI_WIN_NULL;
  int64_t *_writer_count_0_ptr = nullptr;

  MPI_Win _writer_count_1_win = MPI_WIN_NULL;
  int64_t *_writer_count_1_ptr = nullptr;

  bool _prev_queue_num; // Dequeuer-specific

  MPI_Win _offset_0_win = MPI_WIN_NULL;
  MPI_Aint *_offset_0_ptr = nullptr;

  MPI_Win _offset_1_win = MPI_WIN_NULL;
  MPI_Aint *_offset_1_ptr = nullptr;

  MPI_Info _info = MPI_INFO_NULL;

public:
  AMQueue(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Comm comm)
      : _comm{comm}, _dequeuer_rank{dequeuer_rank}, _capacity{capacity} {
    MPI_Comm_rank(comm, &this->_self_rank);
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (this->_self_rank == this->_dequeuer_rank) {
      MPI_Win_allocate(capacity * sizeof(T), sizeof(T), this->_info, comm,
                       &this->_data_0_ptr, &this->_data_0_win);
      MPI_Win_allocate(capacity * sizeof(T), sizeof(T), this->_info, comm,
                       &this->_data_1_ptr, &this->_data_1_win);
      MPI_Win_allocate(sizeof(int64_t), sizeof(MPI_Aint), this->_info, comm,
                       &this->_writer_count_0_ptr, &this->_writer_count_0_win);
      MPI_Win_allocate(sizeof(int64_t), sizeof(MPI_Aint), this->_info, comm,
                       &this->_writer_count_1_ptr, &this->_writer_count_1_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_offset_0_ptr, &this->_offset_0_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_offset_1_ptr, &this->_offset_1_win);
      MPI_Win_allocate(sizeof(bool), sizeof(bool), this->_info, comm,
                       &this->_queue_num_ptr, &this->_queue_num_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_0_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_1_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _writer_count_0_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _writer_count_1_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _offset_0_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _offset_1_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _queue_num_win);
      this->_prev_queue_num = false;
      *this->_writer_count_0_ptr = 0;
      *this->_writer_count_1_ptr = 0;
      *this->_offset_0_ptr = 0;
      *this->_offset_1_ptr = 0;
      *this->_queue_num_ptr = false;
    } else {
      MPI_Win_allocate(0, sizeof(T), this->_info, comm, &this->_data_0_ptr,
                       &this->_data_0_win);
      MPI_Win_allocate(0, sizeof(T), this->_info, comm, &this->_data_1_ptr,
                       &this->_data_1_win);
      MPI_Win_allocate(0, sizeof(int64_t), this->_info, comm,
                       &this->_writer_count_0_ptr, &this->_writer_count_0_win);
      MPI_Win_allocate(0, sizeof(int64_t), this->_info, comm,
                       &this->_writer_count_1_ptr, &this->_writer_count_1_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_offset_0_ptr, &this->_offset_0_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_offset_1_ptr, &this->_offset_1_win);
      MPI_Win_allocate(0, sizeof(bool), this->_info, comm,
                       &this->_queue_num_ptr, &this->_queue_num_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_0_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_1_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _writer_count_0_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _writer_count_1_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _offset_0_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _offset_1_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _queue_num_win);
    }

    MPI_Win_flush_all(this->_data_0_win);
    MPI_Win_flush_all(this->_data_1_win);
    MPI_Win_flush_all(this->_writer_count_0_win);
    MPI_Win_flush_all(this->_writer_count_1_win);
    MPI_Win_flush_all(this->_offset_0_win);
    MPI_Win_flush_all(this->_offset_1_win);
    MPI_Win_flush_all(this->_queue_num_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_data_0_win);
    MPI_Win_flush_all(this->_data_1_win);
    MPI_Win_flush_all(this->_writer_count_0_win);
    MPI_Win_flush_all(this->_writer_count_1_win);
    MPI_Win_flush_all(this->_offset_0_win);
    MPI_Win_flush_all(this->_offset_1_win);
    MPI_Win_flush_all(this->_queue_num_win);
  }

  AMQueue(const AMQueue &) = delete;
  AMQueue &operator=(const AMQueue &) = delete;

  AMQueue(AMQueue &&other) noexcept
      : _comm{other._comm}, _self_rank{other._self_rank},
        _dequeuer_rank{other._dequeuer_rank}, _capacity{other._capacity},
        _data_0_win{other._data_0_win}, _data_0_ptr{other._data_0_ptr},
        _data_1_win{other._data_1_win}, _data_1_ptr{other._data_1_ptr},
        _queue_num_win{other._queue_num_win},
        _queue_num_ptr{other._queue_num_ptr},
        _writer_count_0_win{other._writer_count_0_win},
        _writer_count_0_ptr{other._writer_count_0_ptr},
        _writer_count_1_win{other._writer_count_1_win},
        _writer_count_1_ptr{other._writer_count_1_ptr},
        _prev_queue_num{other._prev_queue_num},
        _offset_0_win{other._offset_0_win}, _offset_0_ptr{other._offset_0_ptr},
        _offset_1_win{other._offset_1_win}, _offset_1_ptr{other._offset_1_ptr},
        _info{other._info} {
    other._data_0_win = MPI_WIN_NULL;
    other._data_0_ptr = nullptr;
    other._data_1_win = MPI_WIN_NULL;
    other._data_1_ptr = nullptr;
    other._queue_num_win = MPI_WIN_NULL;
    other._queue_num_ptr = nullptr;
    other._writer_count_0_win = MPI_WIN_NULL;
    other._writer_count_0_ptr = nullptr;
    other._writer_count_1_win = MPI_WIN_NULL;
    other._writer_count_1_ptr = nullptr;
    other._offset_0_win = MPI_WIN_NULL;
    other._offset_0_ptr = nullptr;
    other._offset_1_win = MPI_WIN_NULL;
    other._offset_1_ptr = nullptr;
    other._info = MPI_INFO_NULL;
  }

  ~AMQueue() {
    if (_info != MPI_INFO_NULL) {
      MPI_Info_free(&_info);
    }

    if (_data_0_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_data_0_win);
      MPI_Win_free(&_data_0_win);
    }
    if (_data_1_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_data_1_win);
      MPI_Win_free(&_data_1_win);
    }
    if (_writer_count_0_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_writer_count_0_win);
      MPI_Win_free(&_writer_count_0_win);
    }
    if (_writer_count_1_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_writer_count_1_win);
      MPI_Win_free(&_writer_count_1_win);
    }
    if (_offset_0_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_offset_0_win);
      MPI_Win_free(&_offset_0_win);
    }
    if (_offset_1_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_offset_1_win);
      MPI_Win_free(&_offset_1_win);
    }
    if (_queue_num_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_queue_num_win);
      MPI_Win_free(&_queue_num_win);
    }
  }

  bool enqueue(const T &data) {
    bool queue_num;
    int64_t writer_count;
    while (true) {
      aread_sync(&queue_num, 0, this->_dequeuer_rank, this->_queue_num_win);
      if (!queue_num) {
        fetch_and_add_sync(&writer_count, 1, 0, this->_dequeuer_rank,
                           this->_writer_count_0_win);
        if (writer_count < 0) {
          fetch_and_add_sync(&writer_count, -1, 0, this->_dequeuer_rank,
                             this->_writer_count_0_win);
          continue;
        }
        break;
      } else {
        fetch_and_add_sync(&writer_count, 1, 0, this->_dequeuer_rank,
                           this->_writer_count_1_win);
        if (writer_count < 0) {
          fetch_and_add_sync(&writer_count, -1, 0, this->_dequeuer_rank,
                             this->_writer_count_1_win);
          continue;
        }
        break;
      }
    }
    MPI_Aint offset;
    fetch_and_add_sync(&offset, 1, 0, this->_dequeuer_rank,
                       queue_num ? this->_offset_1_win : this->_offset_0_win);
    if (offset > this->_capacity) {
      fetch_and_add_sync(&offset, -1, 0, this->_dequeuer_rank,
                         queue_num ? this->_offset_1_win : this->_offset_0_win);
      fetch_and_add_sync(&writer_count, -1, 0, this->_dequeuer_rank,
                         queue_num ? this->_writer_count_1_win
                                   : this->_writer_count_0_win);
      return false;
    }

    write_async(&data, offset, this->_dequeuer_rank,
                queue_num ? this->_data_1_win : this->_data_0_win);
    fetch_and_add_sync(&writer_count, -1, 0, this->_dequeuer_rank,
                       queue_num ? this->_writer_count_1_win
                                 : this->_writer_count_0_win);
    return true;
  }

  bool dequeue(std::vector<T> &output) {
    bool prev_queue_num = this->_prev_queue_num;
    this->_prev_queue_num = !this->_prev_queue_num;
    write_sync(&this->_prev_queue_num, 0, this->_self_rank,
               this->_queue_num_win);
    int64_t writer_count;
    fetch_and_add_sync(&writer_count, -this->_capacity, 0, this->_self_rank,
                       prev_queue_num ? this->_writer_count_1_win
                                      : this->_writer_count_0_win);
    while (writer_count > -this->_capacity) {
      fetch_and_add_sync(&writer_count, 0, 0, this->_self_rank,
                         prev_queue_num ? this->_writer_count_1_win
                                        : this->_writer_count_0_win);
    }
    MPI_Aint offset;
    if (prev_queue_num) {
      offset = *this->_offset_1_ptr;
      *this->_offset_1_ptr = 0;
      *this->_writer_count_1_ptr = 0;
      for (int i = 0; i < offset; ++i) {
        output.push_back(this->_data_1_ptr[i]);
      }
    } else {
      offset = *this->_offset_0_ptr;
      *this->_offset_0_ptr = 0;
      *this->_writer_count_0_ptr = 0;
      for (int i = 0; i < offset; ++i) {
        output.push_back(this->_data_0_ptr[i]);
      }
    }

    if (prev_queue_num) {
      flush(this->_self_rank, this->_offset_1_win);
      flush(this->_self_rank, this->_writer_count_1_win);
    } else {
      flush(this->_self_rank, this->_offset_0_win);
      flush(this->_self_rank, this->_writer_count_0_win);
    }
    return true;
  }
};
