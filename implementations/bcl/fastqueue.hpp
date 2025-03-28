#pragma once

#include "../comm.hpp"
#include <cstring>
#include <mpi.h>
#include <vector>

template <typename T> class FastEnqueuer {
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

  const MPI_Aint _host;
  const MPI_Aint _capacity;

public:
  FastEnqueuer(MPI_Aint capacity, MPI_Aint host, MPI_Aint self_rank,
               MPI_Comm comm)
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
    MPI_Win_lock_all(0, this->_head_win);
    MPI_Win_lock_all(0, this->_tail_win);
    MPI_Win_lock_all(0, this->_data_win);
    MPI_Win_lock_all(0, this->_flag_win);
  }

  ~FastEnqueuer() {
    MPI_Win_unlock_all(this->_head_win);
    MPI_Win_unlock_all(this->_tail_win);
    MPI_Win_unlock_all(this->_data_win);
    MPI_Win_unlock_all(this->_flag_win);
    MPI_Win_free(&this->_head_win);
    MPI_Win_free(&this->_tail_win);
    MPI_Win_free(&this->_data_win);
    MPI_Win_free(&this->_flag_win);
  }

  bool enqueue(const T &data) {
    MPI_Aint old_tail;
    fetch_and_add_sync(&old_tail, 1, 0, this->_host, this->_tail_win);
    MPI_Aint new_tail = old_tail + 1;

    if (new_tail - this->_head_buf > this->_capacity) {
      aread_sync(&this->_head_buf, 0, this->_host, this->_head_win);
      if (new_tail - this->_head_buf > this->_capacity) {
        fetch_and_add_sync(&old_tail, -1, 0, this->_host, this->_tail_win);
        return false;
      }
    }

    awrite_sync(&data, old_tail % this->_capacity, this->_host,
                this->_data_win);
    bool set = true;
    awrite_sync(&set, old_tail % this->_capacity, this->_host, this->_flag_win);

    return true;
  }

  bool enqueue(const std::vector<T> &data) {
    if (data.size() == 0) {
      return true;
    }

    MPI_Aint old_tail;
    fetch_and_add_sync(&old_tail, data.size(), 0, this->_host, this->_tail_win);
    MPI_Aint new_tail = old_tail + data.size();

    if (new_tail - this->_head_buf > this->_capacity) {
      aread_sync(&this->_head_buf, 0, this->_host, this->_head_win);
      if (new_tail - this->_head_buf > this->_capacity) {
        fetch_and_add_sync(&old_tail, -data.size(), 0, this->_host,
                           this->_tail_win);
        return false;
      }
    }

    if (this->_capacity - old_tail % this->_capacity >= data.size()) {
      batch_awrite_sync(data.data(), data.size(), old_tail % this->_capacity,
                        this->_host, this->_data_win);
      std::vector<char> set(data.size(), true);
      batch_awrite_sync(set.data(), data.size(), old_tail % this->_capacity,
                        this->_host, this->_flag_win);
    } else {
      batch_awrite_async(
          data.data(), this->_capacity - old_tail % this->_capacity,
          old_tail % this->_capacity, this->_host, this->_data_win);
      batch_awrite_async(
          data.data() + this->_capacity - old_tail % this->_capacity,
          data.size() - this->_capacity + old_tail % this->_capacity, 0,
          this->_host, this->_data_win);
      MPI_Win_flush(this->_host, this->_data_win);

      std::vector<char> set(data.size(), true);

      batch_awrite_async(
          set.data(), this->_capacity - old_tail % this->_capacity,
          old_tail % this->_capacity, this->_host, this->_flag_win);
      batch_awrite_async(
          set.data() + this->_capacity - old_tail % this->_capacity,
          set.size() - this->_capacity + old_tail % this->_capacity, 0,
          this->_host, this->_flag_win);
      MPI_Win_flush(this->_host, this->_data_win);
    }
    return true;
  }
};

template <typename T> class FastDequeuer {
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

  const MPI_Aint _host;
  const MPI_Aint _capacity;

public:
  FastDequeuer(MPI_Aint capacity, MPI_Aint host, MPI_Aint self_rank,
               MPI_Comm comm)
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

    MPI_Win_lock_all(0, this->_head_win);
    MPI_Win_lock_all(0, this->_tail_win);
    MPI_Win_lock_all(0, this->_data_win);
    MPI_Win_lock_all(0, this->_flag_win);
  }

  ~FastDequeuer() {
    MPI_Win_unlock_all(this->_head_win);
    MPI_Win_unlock_all(this->_tail_win);
    MPI_Win_unlock_all(this->_data_win);
    MPI_Win_unlock_all(this->_flag_win);
    MPI_Win_free(&this->_head_win);
    MPI_Win_free(&this->_tail_win);
    MPI_Win_free(&this->_data_win);
    MPI_Win_free(&this->_flag_win);
  }

  bool dequeue(T *output) {
    MPI_Aint old_head;
    fetch_and_add_sync(&old_head, 1, 0, this->_host, this->_head_win);
    MPI_Aint new_head = old_head + 1;

    if (new_head > this->_tail_buf) {
      aread_sync(&this->_tail_buf, 0, this->_host, this->_tail_win);
      if (new_head > this->_tail_buf) {
        fetch_and_add_sync(&old_head, -1, 0, this->_host, this->_head_win);
        return false;
      }
    }

    bool flag;
    do {
      aread_sync(&flag, old_head % this->_capacity, this->_host,
                 this->_flag_win);
    } while (!flag);

    aread_sync(output, old_head % this->_capacity, this->_host,
               this->_data_win);

    return true;
  }
};
