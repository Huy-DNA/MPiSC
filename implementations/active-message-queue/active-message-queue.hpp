#pragma once

#include "../lib/comm.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <mpi_proto.h>
#include <vector>

template <typename T> class AMEnqueuer {
private:
  MPI_Comm _comm;
  const MPI_Aint _self_rank;
  const MPI_Aint _dequeuer_rank;
  const MPI_Aint _capacity;

  MPI_Win _data_0_win;
  T *_data_0_ptr;

  MPI_Win _data_1_win;
  T *_data_1_ptr;

  MPI_Win _queue_num_win;
  bool *_queue_num_ptr;

  MPI_Win _writer_count_0_win;
  int64_t *_writer_count_0_ptr;

  MPI_Win _writer_count_1_win;
  int64_t *_writer_count_1_ptr;

  MPI_Win _offset_0_win;
  MPI_Aint *_offset_0_ptr;

  MPI_Win _offset_1_win;
  MPI_Aint *_offset_1_ptr;

  MPI_Info _info;

public:
  AMEnqueuer(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
             MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _capacity{capacity} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

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
    MPI_Win_allocate(0, sizeof(bool), this->_info, comm, &this->_queue_num_ptr,
                     &this->_queue_num_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_0_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_1_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _writer_count_0_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _writer_count_1_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _offset_0_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _offset_1_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, _queue_num_win);

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

  AMEnqueuer(const AMEnqueuer &) = delete;
  AMEnqueuer &operator=(const AMEnqueuer &) = delete;

  ~AMEnqueuer() {
    MPI_Info_free(&this->_info);
    MPI_Win_unlock_all(_data_0_win);
    MPI_Win_unlock_all(_data_1_win);
    MPI_Win_unlock_all(_writer_count_0_win);
    MPI_Win_unlock_all(_writer_count_1_win);
    MPI_Win_unlock_all(_offset_0_win);
    MPI_Win_unlock_all(_offset_1_win);
    MPI_Win_unlock_all(_queue_num_win);
    MPI_Win_free(&_data_0_win);
    MPI_Win_free(&_data_1_win);
    MPI_Win_free(&_writer_count_0_win);
    MPI_Win_free(&_writer_count_1_win);
    MPI_Win_free(&_offset_0_win);
    MPI_Win_free(&_offset_1_win);
    MPI_Win_free(&_queue_num_win);
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
};

template <typename T> class AMDequeuer {
private:
  MPI_Comm _comm;
  const MPI_Aint _self_rank;

  MPI_Win _data_0_win;
  T *_data_0_ptr;

  MPI_Win _data_1_win;
  T *_data_1_ptr;

  MPI_Win _queue_num_win;
  bool *_queue_num_ptr;
  bool _prev_queue_num;

  MPI_Win _writer_count_0_win;
  int64_t *_writer_count_0_ptr;

  MPI_Win _writer_count_1_win;
  int64_t *_writer_count_1_ptr;

  MPI_Win _offset_0_win;
  MPI_Aint *_offset_0_ptr;

  MPI_Win _offset_1_win;
  MPI_Aint *_offset_1_ptr;

  const MPI_Aint _capacity;
  MPI_Info _info;

public:
  AMDequeuer(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
             MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _capacity{capacity} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

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

  AMDequeuer(const AMDequeuer &) = delete;
  AMDequeuer &operator=(const AMDequeuer &) = delete;
  ~AMDequeuer() {
    MPI_Info_free(&this->_info);
    MPI_Win_unlock_all(_data_0_win);
    MPI_Win_unlock_all(_data_1_win);
    MPI_Win_unlock_all(_writer_count_0_win);
    MPI_Win_unlock_all(_writer_count_1_win);
    MPI_Win_unlock_all(_offset_0_win);
    MPI_Win_unlock_all(_offset_1_win);
    MPI_Win_unlock_all(_queue_num_win);
    MPI_Win_free(&_data_0_win);
    MPI_Win_free(&_data_1_win);
    MPI_Win_free(&_writer_count_0_win);
    MPI_Win_free(&_writer_count_1_win);
    MPI_Win_free(&_offset_0_win);
    MPI_Win_free(&_offset_1_win);
    MPI_Win_free(&_queue_num_win);
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
