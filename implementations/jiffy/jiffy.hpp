#pragma once

#include "../comm.hpp"
#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T, int segment_size = 1024> class JiffyEnqueuer {
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

  MPI_Comm _comm;
  const MPI_Aint _self_rank;
  const MPI_Aint _dequeuer_rank;

  MPI_Info _info;

  MPI_Win _pool_win;
  char *_pool_ptr;
  MPI_Win _data_break_win;
  MPI_Aint *_data_break_ptr;
  MPI_Win _free_list_break_win;
  MPI_Aint *_free_list_break_ptr;

public:
  JiffyEnqueuer(MPI_Aint dequeuer_rank, MPI_Aint self_rank, MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(0, 1, this->_info, comm, &this->_pool_ptr,
                     &this->_pool_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                     &this->_data_break_ptr, &this->_data_break_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                     &this->_free_list_break_ptr, &this->_free_list_break_win);

    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_pool_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_break_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_free_list_break_win);

    MPI_Win_flush_all(this->_pool_win);
    MPI_Win_flush_all(this->_data_break_win);
    MPI_Win_flush_all(this->_free_list_break_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_pool_win);
    MPI_Win_flush_all(this->_data_break_win);
    MPI_Win_flush_all(this->_free_list_break_win);
  }

  JiffyEnqueuer(const JiffyEnqueuer &) = delete;
  JiffyEnqueuer &operator=(const JiffyEnqueuer &) = delete;

  ~JiffyEnqueuer() {
    MPI_Win_unlock_all(this->_pool_win);
    MPI_Win_unlock_all(this->_data_break_win);
    MPI_Win_unlock_all(this->_free_list_break_win);
    MPI_Win_free(&this->_pool_win);
    MPI_Win_free(&this->_data_break_win);
    MPI_Win_free(&this->_free_list_break_win);
    MPI_Info_free(&this->_info);
  }

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    return false;
  }
};

template <typename T, int segment_size = 1024> class JiffyDequeuer {
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

  MPI_Win _pool_win;
  char *_pool_ptr;
  MPI_Win _data_break_win;
  MPI_Aint *_data_break_ptr;
  MPI_Win _free_list_break_win;
  MPI_Aint *_free_list_break_ptr;

public:
  JiffyDequeuer(MPI_Aint dequeuer_rank, MPI_Aint self_rank, MPI_Comm comm,
                MPI_Aint batch_size = 10)
      : _comm{comm}, _self_rank{self_rank} {
    int size;
    MPI_Comm_size(comm, &size);

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(1 << 24, 1, this->_info, comm, &this->_pool_ptr,
                     &this->_pool_win);
    MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                     &this->_data_break_ptr, &this->_data_break_win);
    MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                     &this->_free_list_break_ptr, &this->_free_list_break_win);

    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_pool_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_break_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_free_list_break_win);

    *this->_data_break_ptr = 0;
    *this->_free_list_break_ptr = 1 << 24;

    MPI_Win_flush_all(this->_pool_win);
    MPI_Win_flush_all(this->_data_break_win);
    MPI_Win_flush_all(this->_free_list_break_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_pool_win);
    MPI_Win_flush_all(this->_data_break_win);
    MPI_Win_flush_all(this->_free_list_break_win);
  }

  JiffyDequeuer(const JiffyDequeuer &) = delete;
  JiffyDequeuer &operator=(const JiffyDequeuer &) = delete;
  ~JiffyDequeuer() {
    MPI_Win_unlock_all(this->_pool_win);
    MPI_Win_unlock_all(this->_data_break_win);
    MPI_Win_unlock_all(this->_free_list_break_win);
    MPI_Win_free(&this->_pool_win);
    MPI_Win_free(&this->_data_break_win);
    MPI_Win_free(&this->_free_list_break_win);
    MPI_Info_free(&this->_info);
  }

  bool dequeue(T *output) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    return false;
  }
};
