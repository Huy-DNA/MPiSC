#pragma once

#include "../comm.hpp"
#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T> class JiffyEnqueuer {
private:
  enum status_t {
    EMPTY,
    HANDLED,
    SET,
  };

  MPI_Comm _comm;
  const MPI_Aint _self_rank;
  const MPI_Aint _dequeuer_rank;

  MPI_Info _info;

  MPI_Win _data_win;
  T *_data_ptr;
  MPI_Win _status_win;
  status_t *_status_ptr;
  MPI_Win _head_win;
  MPI_Aint *_head_ptr;
  MPI_Win _tail_win;
  MPI_Aint *_tail_ptr;

  MPI_Aint _capacity;

public:
  JiffyEnqueuer(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
                MPI_Comm comm)
      : _capacity{capacity}, _comm{comm}, _self_rank{self_rank},
        _dequeuer_rank{dequeuer_rank} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(0, sizeof(T), this->_info, comm, &this->_data_ptr,
                     &this->_data_win);
    MPI_Win_allocate(0, sizeof(status_t), this->_info, comm, &this->_status_ptr,
                     &this->_status_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_head_ptr,
                     &this->_head_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_tail_ptr,
                     &this->_tail_win);

    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_status_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);

    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_status_win);
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_status_win);
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
  }

  JiffyEnqueuer(const JiffyEnqueuer &) = delete;
  JiffyEnqueuer &operator=(const JiffyEnqueuer &) = delete;

  ~JiffyEnqueuer() {
    MPI_Win_unlock_all(this->_data_win);
    MPI_Win_unlock_all(this->_status_win);
    MPI_Win_unlock_all(this->_head_win);
    MPI_Win_unlock_all(this->_tail_win);
    MPI_Win_free(&this->_data_win);
    MPI_Win_free(&this->_status_win);
    MPI_Win_free(&this->_head_win);
    MPI_Win_free(&this->_tail_win);
    MPI_Info_free(&this->_info);
  }

  bool partial_enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    MPI_Aint location;
    fetch_and_add_sync(&location, 1, 0, this->_dequeuer_rank, this->_tail_win);
    while (true) {
      MPI_Aint head;
      aread_sync(&head, 0, this->_dequeuer_rank, this->_head_win);
      if (location - head >= this->_capacity) {
        continue;
      }
    }
    write_sync(&data, location % this->_capacity, this->_dequeuer_rank,
               this->_data_win);
    status_t set = SET;
    awrite_sync(&set, location % this->_capacity, this->_dequeuer_rank,
                this->_status_win);
    return true;
  }

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    MPI_Aint location;
    aread_sync(&location, 0, this->_dequeuer_rank, this->_tail_win);
    while (true) {
      MPI_Aint head;
      aread_sync(&head, 0, this->_dequeuer_rank, this->_head_win);
      if (location - head >= this->_capacity) {
        return false;
      }
      MPI_Aint new_location = location + 1;
      MPI_Aint result;
      compare_and_swap_sync(&location, &new_location, &result, 0, this->_dequeuer_rank, this->_tail_win);
      if (result == location) {
        break;
      }
    }
    write_sync(&data, location % this->_capacity, this->_dequeuer_rank,
               this->_data_win);
    status_t set = SET;
    awrite_sync(&set, location % this->_capacity, this->_dequeuer_rank,
                this->_status_win);
    return true;
  }
};

template <typename T> class JiffyDequeuer {
private:
  enum status_t {
    EMPTY,
    HANDLED,
    SET,
  };

  struct data_t {
    T data;
    status_t status;
  };

  const MPI_Aint _self_rank;
  MPI_Comm _comm;

  MPI_Info _info;

  MPI_Win _data_win;
  T *_data_ptr;
  MPI_Win _status_win;
  status_t *_status_ptr;
  MPI_Win _head_win;
  MPI_Aint *_head_ptr;
  MPI_Win _tail_win;
  MPI_Aint *_tail_ptr;

  MPI_Aint _capacity;

public:
  JiffyDequeuer(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
                MPI_Comm comm, MPI_Aint batch_size = 10)
      : _capacity{capacity}, _comm{comm}, _self_rank{self_rank} {
    int size;
    MPI_Comm_size(comm, &size);

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(capacity * sizeof(T), sizeof(T), this->_info, comm,
                     &this->_data_ptr, &this->_data_win);
    MPI_Win_allocate(capacity * sizeof(status_t), sizeof(status_t), this->_info,
                     comm, &this->_status_ptr, &this->_status_win);
    MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                     &this->_head_ptr, &this->_head_win);
    MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                     &this->_tail_ptr, &this->_tail_win);

    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_status_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);

    for (int i = 0; i < capacity; ++i) {
      this->_status_ptr[i] = EMPTY;
    }
    *this->_head_ptr = 0;
    *this->_tail_ptr = 0;

    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_status_win);
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_status_win);
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
  }

  JiffyDequeuer(const JiffyDequeuer &) = delete;
  JiffyDequeuer &operator=(const JiffyDequeuer &) = delete;
  ~JiffyDequeuer() {
    MPI_Win_unlock_all(this->_data_win);
    MPI_Win_unlock_all(this->_status_win);
    MPI_Win_unlock_all(this->_head_win);
    MPI_Win_unlock_all(this->_tail_win);
    MPI_Win_free(&this->_data_win);
    MPI_Win_free(&this->_status_win);
    MPI_Win_free(&this->_head_win);
    MPI_Win_free(&this->_tail_win);
    MPI_Info_free(&this->_info);
  }

  bool dequeue(T *output) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    return false;
  }
};
