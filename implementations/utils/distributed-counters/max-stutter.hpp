#pragma once

#include "../../comm.hpp"
#include <algorithm>
#include <mpi.h>

class MaxStutterCounter {
private:
  MPI_Aint *_counter_ptr;
  MPI_Win _counter_win;
  MPI_Aint *_buffer;

  int _size;
  MPI_Info _info;
  MPI_Aint _skipped_rank;
  MPI_Aint _host;
  MPI_Aint _order;

public:
  MaxStutterCounter(MPI_Aint skipped_rank, MPI_Aint host, MPI_Comm comm) {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");
    this->_skipped_rank = skipped_rank;
    this->_host = host;

    MPI_Comm_size(comm, &this->_size);

    int rank;
    MPI_Comm_rank(comm, &rank);
    this->_order = rank > this->_skipped_rank ? rank - 1 : rank;

    if (host == rank) {
      MPI_Win_allocate((this->_size - 1) * sizeof(MPI_Aint), sizeof(MPI_Aint),
                       this->_info, comm, &this->_counter_ptr,
                       &this->_counter_win);
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_counter_ptr, &this->_counter_win);
    }
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_counter_win);
    for (int i = 0; i < this->_size - 1; ++i) {
      this->_counter_ptr[i] = 0;
    }
    if (rank == skipped_rank) {
      this->_buffer = nullptr;
    } else {
      this->_buffer = new MPI_Aint[this->_size - 1];
    }

    MPI_Win_flush_all(this->_counter_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_counter_win);
  }
  MaxStutterCounter(const MaxStutterCounter &) = delete;
  MaxStutterCounter &operator=(const MaxStutterCounter &) = delete;
  ~MaxStutterCounter() {
    MPI_Win_unlock_all(this->_counter_win);
    MPI_Win_free(&this->_counter_win);
    MPI_Info_free(&this->_info);
    delete[] this->_buffer;
  }

  // Warning: must not be called on skipped rank
  MPI_Aint get_and_increment() {
    for (int i = 0; i < this->_size - 1; ++i) {
      aread_async(this->_buffer + i, i, this->_host, this->_counter_win);
    }
    flush(this->_host, this->_counter_win);
    MPI_Aint maximum_counter = -1;
    for (int i = 0; i < this->_size - 1; ++i) {
      maximum_counter = std::max(maximum_counter, this->_buffer[i]);
    }
    ++maximum_counter;
    awrite_sync(&maximum_counter, this->_order, this->_host,
                this->_counter_win);
    return maximum_counter - 1;
  }
};
