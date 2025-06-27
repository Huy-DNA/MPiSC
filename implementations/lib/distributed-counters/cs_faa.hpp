#pragma once

#include "../sleep.hpp"
#include "faa.hpp"
#include <atomic>
#include <cstdint>
#include <mpi.h>

class CsFaaCounter {
private:
  constexpr static uint64_t MAX_COUNT = ~((uint64_t)0);

  MPI_Aint *_counter_ptr = nullptr;
  MPI_Win _counter_win;

  MPI_Info _info = MPI_INFO_NULL;
  MPI_Aint _host;

  MPI_Comm _sm_comm = MPI_COMM_NULL;
  int _sm_size;

  MPI_Win _start_counter_win = MPI_WIN_NULL;
  std::atomic<uint64_t> *_start_counter_ptr = nullptr;

  MPI_Win _self_start_counter_win = MPI_WIN_NULL;
  std::atomic<uint64_t> *_self_start_counter_ptr = nullptr;

  MPI_Win _self_remote_counter_win = MPI_WIN_NULL;
  std::atomic<uint64_t> *_self_remote_counter_ptr = nullptr;

  FaaCounter _base_counter;

public:
  CsFaaCounter(MPI_Aint dequeuer_rank, MPI_Comm comm) : _base_counter{dequeuer_rank, comm} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");
    MPI_Comm_split_type(comm, MPI_COMM_TYPE_SHARED, 0, MPI_INFO_NULL,
                        &this->_sm_comm);
    MPI_Comm_size(this->_sm_comm, &this->_sm_size);

    MPI_Win_allocate_shared(sizeof(std::atomic<uint64_t>),
                            sizeof(std::atomic<uint64_t>), this->_info,
                            this->_sm_comm, &this->_self_remote_counter_ptr,
                            &this->_self_remote_counter_win);
    MPI_Win_allocate_shared(sizeof(std::atomic<uint64_t>),
                            sizeof(std::atomic<uint64_t>), this->_info,
                            this->_sm_comm, &this->_start_counter_ptr,
                            &this->_start_counter_win);
    MPI_Win_allocate_shared(sizeof(std::atomic<uint64_t>),
                            sizeof(std::atomic<uint64_t>), this->_info,
                            this->_sm_comm, &this->_self_start_counter_ptr,
                            &this->_self_start_counter_win);

    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_self_remote_counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_start_counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_self_start_counter_win);
    *this->_self_remote_counter_ptr = 0;
    *this->_start_counter_ptr = 0;
    *this->_self_start_counter_ptr = 0;

    MPI_Win_flush_all(this->_self_remote_counter_win);
    MPI_Win_flush_all(this->_start_counter_win);
    MPI_Win_flush_all(this->_self_start_counter_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_self_remote_counter_win);
    MPI_Win_flush_all(this->_start_counter_win);
    MPI_Win_flush_all(this->_self_start_counter_win);
  }

  CsFaaCounter(const CsFaaCounter &) = delete;
  CsFaaCounter &operator=(const CsFaaCounter &) = delete;

  CsFaaCounter(CsFaaCounter &&other) noexcept
      : _counter_ptr(other._counter_ptr), _counter_win(other._counter_win),
        _info(other._info), _host(other._host), _sm_comm(other._sm_comm),
        _sm_size(other._sm_size), _start_counter_win(other._start_counter_win),
        _start_counter_ptr(other._start_counter_ptr),
        _self_start_counter_win(other._self_start_counter_win),
        _self_start_counter_ptr(other._self_start_counter_ptr),
        _self_remote_counter_win(other._self_remote_counter_win),
        _self_remote_counter_ptr(other._self_remote_counter_ptr),
        _base_counter(std::move(other._base_counter)) {
    other._counter_ptr = nullptr;
    other._counter_win = MPI_WIN_NULL;
    other._info = MPI_INFO_NULL;
    other._host = 0;
    other._sm_comm = MPI_COMM_NULL;
    other._sm_size = 0;
    other._start_counter_win = MPI_WIN_NULL;
    other._start_counter_ptr = nullptr;
    other._self_start_counter_win = MPI_WIN_NULL;
    other._self_start_counter_ptr = nullptr;
    other._self_remote_counter_win = MPI_WIN_NULL;
    other._self_remote_counter_ptr = nullptr;
  }

  ~CsFaaCounter() {
    if (_self_remote_counter_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_self_remote_counter_win);
      MPI_Win_free(&this->_self_remote_counter_win);
    }
    if (_start_counter_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_start_counter_win);
      MPI_Win_free(&this->_start_counter_win);
    }
    if (_self_start_counter_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_self_start_counter_win);
      MPI_Win_free(&this->_self_start_counter_win);
    }
    if (_sm_comm != MPI_COMM_NULL) {
      MPI_Comm_free(&this->_sm_comm);
    }
    if (_info != MPI_INFO_NULL) {
      MPI_Info_free(&this->_info);
    }
  }

  inline MPI_Aint get_and_increment() {
    this->_self_remote_counter_ptr->store(MAX_COUNT);
    MPI_Aint size = 1;
    int disp_unit = sizeof(std::atomic<uint64_t>);
    std::atomic<uint64_t> *shared_start_baseptr;
    MPI_Win_shared_query(this->_start_counter_win, 0, &size, &disp_unit,
                         &shared_start_baseptr);
    MPI_Aint self_start = shared_start_baseptr->fetch_add(1);
    this->_self_start_counter_ptr->store(self_start);

    MPI_Aint self_counter = MAX_COUNT;
    for (int i = 0; i < this->_sm_size; ++i) {
      std::atomic<uint64_t> *start_baseptr;
      MPI_Win_shared_query(this->_self_start_counter_win, i, &size, &disp_unit,
                           &start_baseptr);
      if (self_start < start_baseptr->load()) {
        std::atomic<uint64_t> *self_baseptr;
        MPI_Win_shared_query(this->_self_remote_counter_win, i, &size,
                             &disp_unit, &self_baseptr);
        MPI_Aint counter = self_baseptr->load();
        if (counter == MAX_COUNT) {
          for (int retries = 0; retries < 300; ++retries) {
            spin(100);
            MPI_Aint counter = self_baseptr->load();
            if (counter != MAX_COUNT) {
              self_counter = counter;
              break;
            }
          }
        } else {
          self_counter = counter;
        }
      }
    }
    if (self_counter == MAX_COUNT) {
      self_counter = this->_base_counter.get_and_increment();
    }
    this->_self_remote_counter_ptr->store(self_counter);
    return self_counter;
  }
};
