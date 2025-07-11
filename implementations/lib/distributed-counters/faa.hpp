#pragma once
#include "../comm.hpp"
#include <mpi.h>

class FaaCounter {
private:
  MPI_Aint *_counter_ptr = nullptr;
  MPI_Win _counter_win = MPI_WIN_NULL;
  MPI_Info _info = MPI_INFO_NULL;
  MPI_Aint _host;

public:
  FaaCounter(MPI_Aint dequeuer_rank, MPI_Comm comm) {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");
    int size;
    MPI_Comm_size(comm, &size);
    this->_host = (dequeuer_rank + 1) % size;
    int rank;
    MPI_Comm_rank(comm, &rank);
    if (_host == rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_counter_ptr, &this->_counter_win);
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_counter_ptr, &this->_counter_win);
    }
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_counter_win);
    if (_host == rank) {
      *this->_counter_ptr = 0;
    }
    MPI_Win_flush_all(this->_counter_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_counter_win);
  }

  FaaCounter(const FaaCounter &) = delete;
  FaaCounter &operator=(const FaaCounter &) = delete;

  FaaCounter(FaaCounter &&other) noexcept
      : _counter_ptr(other._counter_ptr), _counter_win(other._counter_win),
        _info(other._info), _host(other._host) {
    other._counter_ptr = nullptr;
    other._counter_win = MPI_WIN_NULL;
    other._info = MPI_INFO_NULL;
    other._host = 0;
  }

  ~FaaCounter() {
    if (_counter_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(this->_counter_win);
      MPI_Win_free(&this->_counter_win);
    }
    if (_info != MPI_INFO_NULL) {
      MPI_Info_free(&this->_info);
    }
  }

  inline MPI_Aint get_and_increment() {
    MPI_Aint old_counter;
    fetch_and_add_sync(&old_counter, 1, 0, this->_host, this->_counter_win);
    return old_counter;
  }
};
