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

  MPI_Info _info;

public:
  FastEnqueuer(MPI_Aint capacity, MPI_Aint host, MPI_Aint self_rank,
               MPI_Comm comm)
      : _host{host}, _head_buf{0}, _capacity{capacity} {
    int rank;
    MPI_Comm_rank(comm, &rank);

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (host == rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_head_ptr, &this->_head_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_tail_ptr, &this->_tail_win);
      MPI_Win_allocate(capacity * sizeof(T), sizeof(T), this->_info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(capacity * sizeof(bool), sizeof(bool), this->_info, comm,
                       &this->_flag_ptr, &this->_flag_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_flag_win);
      *this->_head_ptr = 0;
      *this->_tail_ptr = 0;
      memset(this->_data_ptr, 0, capacity * sizeof(T));
      memset(this->_flag_ptr, 0, capacity * sizeof(bool));
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_head_ptr,
                       &this->_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_tail_ptr,
                       &this->_tail_win);
      MPI_Win_allocate(0, sizeof(T), this->_info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(bool), this->_info, comm, &this->_flag_ptr,
                       &this->_flag_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_flag_win);
    }
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_flag_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_flag_win);
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
    MPI_Info_free(&this->_info);
  }

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

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
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

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

    const uint64_t size = data.size();
    for (int i = 0; i < size; ++i) {
      const uint64_t disp = (old_tail + i) % this->_capacity;
      awrite_async(data.data() + i, disp, this->_host, this->_data_win);
    }
    flush(this->_host, this->_data_win);
    for (int i = 0; i < size; ++i) {
      const uint64_t disp = (old_tail + i) % this->_capacity;
      bool t = true;
      awrite_async(&t, disp, this->_host, this->_flag_win);
    }
    flush(this->_host, this->_flag_win);

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
  MPI_Info _info;

public:
  FastDequeuer(MPI_Aint capacity, MPI_Aint host, MPI_Aint self_rank,
               MPI_Comm comm)
      : _host{host}, _tail_buf{0}, _capacity{capacity} {
    int rank;
    MPI_Comm_rank(comm, &rank);

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (host == rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_head_ptr, &this->_head_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_tail_ptr, &this->_tail_win);
      MPI_Win_allocate(capacity * sizeof(T), sizeof(T), this->_info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(capacity * sizeof(bool), sizeof(bool), this->_info, comm,
                       &this->_flag_ptr, &this->_flag_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_flag_win);
      *this->_head_ptr = 0;
      *this->_tail_ptr = 0;
      memset(this->_data_ptr, 0, capacity * sizeof(T));
      memset(this->_flag_ptr, 0, capacity * sizeof(bool));
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_head_ptr,
                       &this->_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_tail_ptr,
                       &this->_tail_win);
      MPI_Win_allocate(0, sizeof(T), this->_info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(bool), this->_info, comm, &this->_flag_ptr,
                       &this->_flag_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_flag_win);
    }
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_flag_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_flag_win);
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
    MPI_Info_free(&this->_info);
  }

  bool dequeue(T *output) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    MPI_Aint old_head;
    aread_sync(&old_head, 0, this->_host, this->_head_win);
    MPI_Aint new_head = old_head + 1;

    if (new_head > this->_tail_buf) {
      aread_sync(&this->_tail_buf, 0, this->_host, this->_tail_win);
      if (new_head > this->_tail_buf) {
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

    bool unset = false;
    awrite_sync(&unset, old_head % this->_capacity, this->_host,
               this->_flag_win);
    awrite_sync(&new_head, 0, this->_host, this->_head_win);

    return true;
  }
};
