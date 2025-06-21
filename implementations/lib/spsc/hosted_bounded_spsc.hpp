#pragma once

#include "../comm.hpp"
#include <algorithm>
#include <mpi.h>
#include <vector>

template <typename data_t> class HostedBoundedSpsc {
  int _self_rank;
  const MPI_Aint _dequeuer_rank;

  const MPI_Aint _capacity;

  MPI_Win _data_win = MPI_WIN_NULL;
  data_t *_data_ptr = nullptr;

  MPI_Win _first_win = MPI_WIN_NULL;
  MPI_Aint *_first_ptr = nullptr;
  std::vector<MPI_Aint> _first_buf;

  MPI_Win _last_win = MPI_WIN_NULL;
  MPI_Aint *_last_ptr = nullptr;
  MPI_Win _enqueuer_local_last_win = MPI_WIN_NULL;
  MPI_Aint *_enqueuer_local_last_ptr = nullptr;
  std::vector<MPI_Aint> _last_buf;

  MPI_Info _info = MPI_INFO_NULL;

  int _comm_size;
  MPI_Aint _batch_size;
  data_t **_cached_data = nullptr;
  MPI_Aint *_cached_size = nullptr;

public:
  HostedBoundedSpsc(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Comm comm,
                    MPI_Aint batch_size = 10)
      : _dequeuer_rank{dequeuer_rank}, _capacity{capacity}, _first_buf{0},
        _last_buf{0}, _batch_size{batch_size} {
    MPI_Comm_rank(comm, &this->_self_rank);
    MPI_Comm_size(comm, &this->_comm_size);
    _first_buf = std::vector<MPI_Aint>(this->_comm_size);
    _last_buf = std::vector<MPI_Aint>(this->_comm_size);

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (this->_self_rank == dequeuer_rank) {
      MPI_Win_allocate(capacity * sizeof(data_t) * this->_comm_size,
                       sizeof(data_t), this->_info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(this->_comm_size * sizeof(MPI_Aint), sizeof(MPI_Aint),
                       this->_info, comm, &this->_first_ptr, &this->_first_win);
      MPI_Win_allocate(this->_comm_size * sizeof(MPI_Aint), sizeof(MPI_Aint),
                       this->_info, comm, &this->_last_ptr, &this->_last_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_enqueuer_local_last_ptr,
                       &this->_enqueuer_local_last_win);
      this->_cached_data =
          (data_t **)malloc(sizeof(data_t *) * this->_comm_size);
      this->_cached_size =
          (MPI_Aint *)malloc(sizeof(MPI_Aint) * this->_comm_size);
      for (int i = 0; i < this->_comm_size; ++i) {
        this->_cached_data[i] =
            (data_t *)malloc(sizeof(data_t) * this->_batch_size);
        this->_cached_size[i] = 0;
      }

      MPI_Win_lock_all(MPI_MODE_NOCHECK, _first_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _last_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _enqueuer_local_last_win);
      for (int i = 0; i < this->_comm_size; ++i) {
        this->_first_ptr[i] = 0;
        this->_last_ptr[i] = 0;
      }
    } else {
      MPI_Win_allocate(0, sizeof(data_t), this->_info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_first_ptr, &this->_first_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_last_ptr,
                       &this->_last_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_enqueuer_local_last_ptr,
                       &this->_enqueuer_local_last_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _first_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _last_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, _enqueuer_local_last_win);
      *_enqueuer_local_last_ptr = 0;
    }
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_first_win);
    MPI_Win_flush_all(this->_last_win);
    MPI_Win_flush_all(this->_enqueuer_local_last_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_first_win);
    MPI_Win_flush_all(this->_last_win);
    MPI_Win_flush_all(this->_enqueuer_local_last_win);
  }

  HostedBoundedSpsc(HostedBoundedSpsc &&other) noexcept
      : _self_rank(other._self_rank), _dequeuer_rank(other._dequeuer_rank),
        _capacity(other._capacity), _data_win(other._data_win),
        _data_ptr(other._data_ptr), _first_win(other._first_win),
        _first_ptr(other._first_ptr), _first_buf(std::move(other._first_buf)),
        _last_win(other._last_win), _last_ptr(other._last_ptr),
        _enqueuer_local_last_win(other._enqueuer_local_last_win),
        _enqueuer_local_last_ptr(other._enqueuer_local_last_ptr),
        _last_buf(std::move(other._last_buf)), _info(other._info),
        _comm_size(other._comm_size), _batch_size(other._batch_size),
        _cached_data(other._cached_data), _cached_size(other._cached_size) {

    other._data_win = MPI_WIN_NULL;
    other._data_ptr = nullptr;
    other._first_win = MPI_WIN_NULL;
    other._first_ptr = nullptr;
    other._last_win = MPI_WIN_NULL;
    other._last_ptr = nullptr;
    other._enqueuer_local_last_win = MPI_WIN_NULL;
    other._enqueuer_local_last_ptr = nullptr;
    other._info = MPI_INFO_NULL;
    other._cached_data = nullptr;
    other._cached_size = nullptr;
  }

  HostedBoundedSpsc(const HostedBoundedSpsc &) = delete;
  HostedBoundedSpsc &operator=(const HostedBoundedSpsc &) = delete;
  HostedBoundedSpsc &operator=(HostedBoundedSpsc &&) = delete;

  ~HostedBoundedSpsc() {
    if (_data_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(_first_win);
      MPI_Win_unlock_all(_last_win);
      MPI_Win_unlock_all(_enqueuer_local_last_win);
      MPI_Win_unlock_all(_data_win);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
      MPI_Win_free(&this->_enqueuer_local_last_win);
    }

    if (_info != MPI_INFO_NULL) {
      MPI_Info_free(&this->_info);
    }

    if (this->_self_rank == this->_dequeuer_rank &&
        this->_cached_data != nullptr) {
      for (int i = 0; i < this->_comm_size; ++i) {
        free(this->_cached_data[i]);
      }
      free(this->_cached_data);
      free(this->_cached_size);
    }
  }

  int start_offset(int rank) { return this->_capacity * rank; }

  bool enqueue(const data_t &data) {
    MPI_Aint new_last = this->_last_buf[this->_self_rank] + 1;

    if (new_last - this->_first_buf[this->_self_rank] > this->_capacity) {
      aread_sync(&this->_first_buf[this->_self_rank], this->_self_rank,
                 this->_dequeuer_rank, this->_first_win);
      if (new_last - this->_first_buf[this->_self_rank] > this->_capacity) {
        return false;
      }
    }

    awrite_sync(&data,
                start_offset(this->_self_rank) +
                    this->_last_buf[this->_self_rank] % this->_capacity,
                this->_dequeuer_rank, this->_data_win);
    awrite_sync(&new_last, 0, this->_self_rank, this->_enqueuer_local_last_win);
    if (new_last % 10 == 0) {
      awrite_sync(&new_last, this->_self_rank, this->_dequeuer_rank,
                  this->_last_win);
    }
    this->_last_buf[this->_self_rank] = new_last;

    return true;
  }

  bool enqueue(const std::vector<data_t> &data) {
    MPI_Aint new_last = this->_last_buf[this->_self_rank] + data.size();

    if (new_last - this->_first_buf[this->_self_rank] > this->_capacity) {
      aread_sync(&this->_first_buf[this->_self_rank], this->_self_rank,
                 this->_dequeuer_rank, this->_first_win);
      if (new_last - this->_first_buf[this->_self_rank] > this->_capacity) {
        return false;
      }
    }

    const uint64_t size = data.size();
    for (int i = 0; i < size; ++i) {
      const uint64_t disp =
          (this->_last_buf[this->_self_rank] + i) % this->_capacity;
      awrite_async(data.data() + i, start_offset(this->_self_rank) + disp,
                   this->_dequeuer_rank, this->_data_win);
    }
    flush(this->_dequeuer_rank, this->_data_win);
    awrite_sync(&new_last, this->_self_rank, this->_dequeuer_rank,
                this->_last_win);
    this->_last_buf[this->_self_rank] = new_last;

    return true;
  }

  bool e_read_front(data_t *output) {
    if (this->_first_buf[this->_self_rank] >=
        this->_last_buf[this->_self_rank]) {
      return false;
    }
    aread_sync(&this->_first_buf[this->_self_rank], this->_self_rank,
               this->_dequeuer_rank, this->_first_win);
    if (this->_first_buf >= this->_last_buf) {
      return false;
    }

    data_t data;
    aread_sync(&data,
               start_offset(this->_self_rank) +
                   this->_first_buf[this->_self_rank] % this->_capacity,
               this->_dequeuer_rank, this->_data_win);

    *output = data;
    return true;
  }

  bool dequeue(data_t *output, int enqueuer_rank) {
    MPI_Aint new_first = this->_first_buf[enqueuer_rank] + 1;
    if (new_first > this->_last_buf[enqueuer_rank]) {
      aread_sync(&this->_last_buf[enqueuer_rank], enqueuer_rank,
                 this->_self_rank, this->_last_win);
      if (new_first > this->_last_buf[enqueuer_rank]) {
        aread_sync(&this->_last_buf[enqueuer_rank], 0, enqueuer_rank,
                   this->_enqueuer_local_last_win);
        if (new_first > this->_last_buf[enqueuer_rank]) {
          return false;
        }
      }
    }

    if (this->_cached_size[enqueuer_rank] > 0) {
      *output = this->_cached_data[enqueuer_rank]
                                  [this->_cached_size[enqueuer_rank] - 1];
      --this->_cached_size[enqueuer_rank];
    } else {
      aread_async(output,
                  start_offset(enqueuer_rank) +
                      this->_first_buf[enqueuer_rank] % this->_capacity,
                  this->_dequeuer_rank, this->_data_win);
      int nreads = std::min(this->_batch_size,
                            this->_last_buf[enqueuer_rank] - new_first);
      this->_cached_size[enqueuer_rank] = nreads;
      for (int i = 0; i < nreads; ++i) {
        aread_async(this->_cached_data[enqueuer_rank] + nreads - i - 1,
                    start_offset(enqueuer_rank) +
                        (new_first + i) % this->_capacity,
                    this->_dequeuer_rank, this->_data_win);
      }
      flush(this->_dequeuer_rank, this->_data_win);
    }
    awrite_sync(&new_first, enqueuer_rank, this->_self_rank, this->_first_win);
    this->_first_buf[enqueuer_rank] = new_first;

    return true;
  }

  bool d_read_front(data_t *output, int enqueuer_rank) {
    if (this->_first_buf[enqueuer_rank] >= this->_last_buf[enqueuer_rank]) {
      aread_sync(&this->_last_buf[enqueuer_rank], enqueuer_rank,
                 this->_self_rank, this->_last_win);
      if (this->_first_buf[enqueuer_rank] >= this->_last_buf[enqueuer_rank]) {
        aread_sync(&this->_last_buf[enqueuer_rank], 0, enqueuer_rank,
                   this->_enqueuer_local_last_win);
        if (this->_first_buf[enqueuer_rank] >= this->_last_buf[enqueuer_rank]) {
          return false;
        }
      }
    }

    if (this->_cached_size[enqueuer_rank] <= 0) {
      int nreads =
          std::min(this->_batch_size, this->_last_buf[enqueuer_rank] -
                                          this->_first_buf[enqueuer_rank]);
      this->_cached_size[enqueuer_rank] = nreads;
      for (int i = 0; i < nreads; ++i) {
        aread_async(this->_cached_data[enqueuer_rank] + nreads - i - 1,
                    start_offset(enqueuer_rank) +
                        (this->_first_buf[enqueuer_rank] + i) % this->_capacity,
                    this->_dequeuer_rank, this->_data_win);
      }
      flush(this->_dequeuer_rank, this->_data_win);
    }
    *output = this->_cached_data[enqueuer_rank]
                                [this->_cached_size[enqueuer_rank] - 1];
    return true;
  }
};
