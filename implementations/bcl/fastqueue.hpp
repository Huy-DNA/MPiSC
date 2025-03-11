#pragma once

#include <cstring>
#include <mpi.h>

template <typename T> class FqEnqueuer {
private:
  MPI_Win _head_win;
  MPI_Aint *_head_ptr;

  MPI_Win _tail_win;
  MPI_Aint *_tail_ptr;

  MPI_Win _data_win;
  MPI_Aint *_data_ptr;

  MPI_Aint _head_buf;

  unsigned int _host;

  struct entry_t {
    T data;
    bool flag;
  };

public:
  FqEnqueuer(unsigned int host, unsigned int capacity, MPI_Comm comm)
      : _host{host}, _head_buf{0} {
    int rank;
    MPI_Comm_rank(comm, &rank);

    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    if (host == rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_head_ptr, &this->_head_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_tail_ptr, &this->_tail_win);
      MPI_Win_allocate(capacity * sizeof(entry_t), sizeof(entry_t), info, comm,
                       &this->_data_ptr, &this->_data_win);

      MPI_Win_lock_all(0, this->_head_win);
      MPI_Win_lock_all(0, this->_tail_win);
      MPI_Win_lock_all(0, this->_data_win);
      *this->_head_ptr = 0;
      *this->_tail_ptr = 0;
      memset(this->_data_ptr, 0, capacity * sizeof(entry_t));
      MPI_Win_unlock_all(this->_head_win);
      MPI_Win_unlock_all(this->_tail_win);
      MPI_Win_unlock_all(this->_data_win);
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_head_ptr,
                       &this->_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_tail_ptr,
                       &this->_tail_win);
      MPI_Win_allocate(0, sizeof(entry_t), info, comm, &this->_data_ptr,
                       &this->_data_win);
    }
    MPI_Barrier(comm);
  }
};

template <typename T> class FqDequeuer {
private:
  MPI_Win _head_win;
  MPI_Aint *_head_ptr;

  MPI_Win _tail_win;
  MPI_Aint *_tail_ptr;

  MPI_Win _data_win;
  MPI_Aint *_data_ptr;

  MPI_Aint _tail_buf;

  unsigned int _host;

  struct entry_t {
    T data;
    bool flag;
  };

public:
  FqDequeuer(unsigned int host, unsigned int capacity, MPI_Comm comm)
      : _host{host}, _tail_buf{0} {
    int rank;
    MPI_Comm_rank(comm, &rank);

    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    if (host == rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_head_ptr, &this->_head_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_tail_ptr, &this->_tail_win);
      MPI_Win_allocate(capacity * sizeof(entry_t), sizeof(entry_t), info, comm,
                       &this->_data_ptr, &this->_data_win);

      MPI_Win_lock_all(this->_head_win);
      MPI_Win_lock_all(this->_tail_win);
      MPI_Win_lock_all(0, this->_data_win);
      *this->_head_ptr = 0;
      *this->_tail_ptr = 0;
      memset(this->_data_ptr, 0, capacity * sizeof(entry_t));
      MPI_Win_unlock_all(this->_head_win);
      MPI_Win_unlock_all(this->_tail_win);
      MPI_Win_unlock_all(this->_data_win);
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_head_ptr,
                       &this->_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_tail_ptr,
                       &this->_tail_win);
      MPI_Win_allocate(0, sizeof(T), info, comm, &this->_data_ptr,
                       &this->_data_win);
    }
    MPI_Barrier(comm);
  }
};
