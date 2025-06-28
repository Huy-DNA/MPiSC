#pragma once
#include "../comm.hpp"
#include <cstdint>
#include <mpi.h>

class Faa2C3Counter {
private:
  MPI_Aint *_counter_ptr = nullptr;
  MPI_Win _counter_win = MPI_WIN_NULL;
  MPI_Info _info = MPI_INFO_NULL;
  MPI_Aint _host_1;
  MPI_Aint _host_2;
  MPI_Aint _host_3;
  int _cur_c;

public:
  Faa2C3Counter(MPI_Aint dequeuer_rank, MPI_Comm comm) : _cur_c(0) {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");
    int size;
    MPI_Comm_size(comm, &size);
    this->_host_1 = (dequeuer_rank + 1) % size;
    this->_host_2 = (dequeuer_rank + 2) % size;
    this->_host_3 = (dequeuer_rank + 2) % size;
    int rank;
    MPI_Comm_rank(comm, &rank);
    if (_host_1 == rank || _host_2 == rank || _host_3 == rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_counter_ptr, &this->_counter_win);
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_counter_ptr, &this->_counter_win);
    }
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_counter_win);
    if (_host_1 == rank || _host_2 == rank || _host_3 == rank) {
      *this->_counter_ptr = 0;
    }
    MPI_Win_flush_all(this->_counter_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_counter_win);
  }

  Faa2C3Counter(const Faa2C3Counter &) = delete;
  Faa2C3Counter &operator=(const Faa2C3Counter &) = delete;

  Faa2C3Counter(Faa2C3Counter &&other) noexcept
      : _counter_ptr(other._counter_ptr), _counter_win(other._counter_win),
        _info(other._info), _host_1(other._host_1), _host_2(other._host_2),
        _host_3(other._host_3) {
    other._counter_ptr = nullptr;
    other._counter_win = MPI_WIN_NULL;
    other._info = MPI_INFO_NULL;
  }

  ~Faa2C3Counter() {
    if (_counter_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(this->_counter_win);
      MPI_Win_free(&this->_counter_win);
    }
    if (_info != MPI_INFO_NULL) {
      MPI_Info_free(&this->_info);
    }
  }

  inline uint64_t get_and_increment() {
    MPI_Aint first_counter;
    MPI_Aint second_counter;
    if (this->_cur_c == 0) {
      fetch_and_add_async(&first_counter, 1, 0, this->_host_1,
                          this->_counter_win);
      fetch_and_add_async(&second_counter, 1, 0, this->_host_2,
                          this->_counter_win);
      flush(this->_host_1, this->_counter_win);
      flush(this->_host_2, this->_counter_win);
    } else if (this->_cur_c == 1) {
      fetch_and_add_async(&first_counter, 1, 0, this->_host_2,
                          this->_counter_win);
      fetch_and_add_async(&second_counter, 1, 0, this->_host_3,
                          this->_counter_win);
      flush(this->_host_2, this->_counter_win);
      flush(this->_host_3, this->_counter_win);
    } else {
      fetch_and_add_async(&first_counter, 1, 0, this->_host_3,
                          this->_counter_win);
      fetch_and_add_async(&second_counter, 1, 0, this->_host_1,
                          this->_counter_win);
      flush(this->_host_3, this->_counter_win);
      flush(this->_host_1, this->_counter_win);
    }
    return first_counter < second_counter ? first_counter : second_counter;
  }
};
