#pragma once

#include "../comm.hpp"
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

  MPI_Win _flag_win;
  bool *_flag_ptr;

  MPI_Aint _head_buf;

  const unsigned int _host;
  const unsigned int _capacity;

public:
  FqEnqueuer(unsigned int host, unsigned int capacity, MPI_Comm comm)
      : _host{host}, _head_buf{0}, _capacity{capacity} {
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
      MPI_Win_allocate(capacity * sizeof(T), sizeof(T), info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(capacity * sizeof(bool), sizeof(bool), info, comm,
                       &this->_flag_ptr, &this->_flag_win);

      MPI_Win_lock_all(0, this->_head_win);
      MPI_Win_lock_all(0, this->_tail_win);
      MPI_Win_lock_all(0, this->_data_win);
      MPI_Win_lock_all(0, this->_flag_win);
      *this->_head_ptr = 0;
      *this->_tail_ptr = 0;
      memset(this->_data_ptr, 0, capacity * sizeof(T));
      memset(this->_flag_ptr, 0, capacity * sizeof(bool));
      MPI_Win_unlock_all(this->_head_win);
      MPI_Win_unlock_all(this->_tail_win);
      MPI_Win_unlock_all(this->_data_win);
      MPI_Win_unlock_all(this->_flag_win);
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_head_ptr,
                       &this->_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_tail_ptr,
                       &this->_tail_win);
      MPI_Win_allocate(0, sizeof(T), info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(bool), info, comm, &this->_flag_ptr,
                       &this->_flag_win);
    }
    MPI_Barrier(comm);
  }

  bool enqueue(const T &data) {
    MPI_Win_lock_all(0, this->_head_win);
    MPI_Win_lock_all(0, this->_tail_win);
    MPI_Win_lock_all(0, this->_data_win);
    MPI_Win_lock_all(0, this->_flag_win);

    MPI_Aint old_tail;
    fetch_and_add_sync(&old_tail, 1, 0, this->_host, this->_tail_win);
    MPI_Aint new_tail = old_tail + 1;

    if (new_tail - this->_head_buf > this->_capacity) {
      aread_sync(&this->_head_buf, 0, this->_host, this->_head_win);
      if (new_tail - this->_head_buf > this->_capacity) {
        fetch_and_add_sync(&old_tail, -1, 0, this->_host, this->_tail_win);
        MPI_Win_unlock_all(this->_head_win);
        MPI_Win_unlock_all(this->_tail_win);
        MPI_Win_unlock_all(this->_data_win);
        MPI_Win_unlock_all(this->_flag_win);
        return false;
      }
    }

    awrite_sync(&data, old_tail % this->_capacity, this->_host,
                this->_data_win);
    bool set = true;
    awrite_sync(&set, old_tail % this->_capacity, this->_host, this->_flag_win);

    MPI_Win_unlock_all(this->_head_win);
    MPI_Win_unlock_all(this->_tail_win);
    MPI_Win_unlock_all(this->_data_win);
    MPI_Win_unlock_all(this->_flag_win);
    return true;
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

  MPI_Win _flag_win;
  bool *_flag_ptr;

  MPI_Aint _tail_buf;

  const unsigned int _host;
  const unsigned int _capacity;

public:
  FqDequeuer(unsigned int host, unsigned int capacity, MPI_Comm comm)
      : _host{host}, _tail_buf{0}, _capacity{capacity} {
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
      MPI_Win_allocate(capacity * sizeof(T), sizeof(T), info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(capacity * sizeof(bool), sizeof(bool), info, comm,
                       &this->_flag_ptr, &this->_flag_win);

      MPI_Win_lock_all(0, this->_head_win);
      MPI_Win_lock_all(0, this->_tail_win);
      MPI_Win_lock_all(0, this->_data_win);
      MPI_Win_lock_all(0, this->_flag_win);
      *this->_head_ptr = 0;
      *this->_tail_ptr = 0;
      memset(this->_data_ptr, 0, capacity * sizeof(T));
      memset(this->_flag_ptr, 0, capacity * sizeof(bool));
      MPI_Win_unlock_all(this->_head_win);
      MPI_Win_unlock_all(this->_tail_win);
      MPI_Win_unlock_all(this->_data_win);
      MPI_Win_unlock_all(this->_flag_win);
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_head_ptr,
                       &this->_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_tail_ptr,
                       &this->_tail_win);
      MPI_Win_allocate(0, sizeof(T), info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(bool), info, comm, &this->_flag_ptr,
                       &this->_flag_win);
    }
    MPI_Barrier(comm);
  }

  bool dequeue(T *output) {
    MPI_Win_lock_all(0, this->_head_win);
    MPI_Win_lock_all(0, this->_tail_win);
    MPI_Win_lock_all(0, this->_data_win);
    MPI_Win_lock_all(0, this->_flag_win);

    MPI_Aint old_head;
    fetch_and_add_sync(&old_head, 1, 0, this->_host, this->_head_win);
    MPI_Aint new_head = old_head + 1;

    if (new_head > this->_tail_buf) {
      aread_sync(&this->_tail_buf, 0, this->_host, this->_tail_win);
      if (new_head > this->_tail_buf) {
        fetch_and_add_sync(&old_head, -1, 0, this->_host, this->_head_win);
        MPI_Win_unlock_all(this->_head_win);
        MPI_Win_unlock_all(this->_tail_win);
        MPI_Win_unlock_all(this->_data_win);
        MPI_Win_unlock_all(this->_flag_win);
        return false;
      }
    }

    bool flag;
    do {
      aread_sync(&flag, old_head % this->_capacity, this->_host,
                 this->_flag_win);
    } while (!flag);

    aread_async(output, old_head % this->_capacity, this->_host,
                this->_data_win);
    flag = false;
    awrite_async(&flag, old_head % this->_capacity, this->_host,
                 this->_flag_win);

    MPI_Win_unlock_all(this->_head_win);
    MPI_Win_unlock_all(this->_tail_win);
    MPI_Win_unlock_all(this->_data_win);
    MPI_Win_unlock_all(this->_flag_win);
    return true;
  }
};
