#pragma once

#include "./comm.hpp"
#include <algorithm>
#include <vector>

template <typename data_t> class SpscEnqueuer {
  const MPI_Aint _self_rank;
  const MPI_Aint _dequeuer_rank;

  const MPI_Aint _capacity;

  MPI_Win _data_win;
  data_t *_data_ptr;

  MPI_Win _first_win;
  MPI_Aint *_first_ptr;
  MPI_Aint _first_buf;

  MPI_Win _last_win;
  MPI_Aint *_last_ptr;
  MPI_Win _enqueuer_local_last_win;
  MPI_Aint *_enqueuer_local_last_ptr;
  MPI_Aint _last_buf;
  MPI_Info _info;

public:
  SpscEnqueuer(MPI_Aint capacity, MPI_Aint self_rank, MPI_Aint dequeuer_rank,
               MPI_Comm comm)
      : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _capacity{capacity}, _first_buf{0}, _last_buf{0} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(capacity * sizeof(data_t), sizeof(data_t), this->_info,
                     comm, &this->_data_ptr, &this->_data_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_first_ptr,
                     &this->_first_win);
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

  ~SpscEnqueuer() {
    MPI_Win_unlock_all(_first_win);
    MPI_Win_unlock_all(_last_win);
    MPI_Win_unlock_all(_enqueuer_local_last_win);
    MPI_Win_unlock_all(_data_win);
    MPI_Win_free(&this->_data_win);
    MPI_Win_free(&this->_first_win);
    MPI_Win_free(&this->_last_win);
    MPI_Win_free(&this->_enqueuer_local_last_win);
    MPI_Info_free(&this->_info);
  }

  bool enqueue(const data_t &data) {
    MPI_Aint new_last = this->_last_buf + 1;

    if (new_last - this->_first_buf > this->_capacity) {
      aread_sync(&this->_first_buf, this->_self_rank, this->_dequeuer_rank,
                 this->_first_win);
      if (new_last - this->_first_buf > this->_capacity) {
        return false;
      }
    }

    awrite_sync(&data, this->_last_buf % this->_capacity, this->_self_rank,
                this->_data_win);
    awrite_sync(&new_last, 0, this->_self_rank, this->_enqueuer_local_last_win);
    if (new_last % 10 == 0) {
      awrite_sync(&new_last, this->_self_rank, this->_dequeuer_rank,
                  this->_last_win);
    }
    this->_last_buf = new_last;

    return true;
  }

  bool enqueue(const std::vector<data_t> &data) {
    MPI_Aint new_last = this->_last_buf + data.size();

    if (new_last - this->_first_buf > this->_capacity) {
      aread_sync(&this->_first_buf, this->_self_rank, this->_dequeuer_rank,
                 this->_first_win);
      if (new_last - this->_first_buf > this->_capacity) {
        return false;
      }
    }

    const uint64_t size = data.size();
    for (int i = 0; i < size; ++i) {
      const uint64_t disp = (this->_last_buf + i) % this->_capacity;
      awrite_async(data.data() + i, disp, this->_self_rank, this->_data_win);
    }
    flush(this->_self_rank, this->_data_win);
    awrite_sync(&new_last, this->_self_rank, this->_dequeuer_rank,
                this->_last_win);
    this->_last_buf = new_last;

    return true;
  }

  bool read_front(data_t *output) {
    if (this->_first_buf >= this->_last_buf) {
      return false;
    }
    aread_sync(&this->_first_buf, this->_self_rank, this->_dequeuer_rank,
               this->_first_win);
    if (this->_first_buf >= this->_last_buf) {
      return false;
    }

    data_t data;
    aread_sync(&data, this->_first_buf % this->_capacity, this->_self_rank,
               this->_data_win);

    *output = data;
    return true;
  }
};

template <typename data_t> class SpscDequeuer {
  const MPI_Aint _self_rank;

  const MPI_Aint _capacity;

  MPI_Win _data_win;
  data_t *_data_ptr;

  MPI_Win _first_win;
  MPI_Aint *_first_ptr;
  std::vector<MPI_Aint> _first_buf;

  MPI_Win _last_win;
  MPI_Aint *_last_ptr;
  std::vector<MPI_Aint> _last_buf;
  MPI_Win _enqueuer_local_last_win;
  MPI_Aint *_enqueuer_local_last_ptr;
  MPI_Info _info;

  int _comm_size;
  MPI_Aint _batch_size;
  data_t **_cached_data;
  MPI_Aint *_cached_size;

public:
  SpscDequeuer(MPI_Aint capacity, MPI_Aint self_rank, MPI_Comm comm,
               MPI_Aint batch_size)
      : _self_rank{self_rank}, _capacity{capacity}, _batch_size{batch_size} {
    MPI_Comm_size(comm, &this->_comm_size);
    _first_buf = std::vector<MPI_Aint>(this->_comm_size);
    _last_buf = std::vector<MPI_Aint>(this->_comm_size);

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Win_allocate(0, sizeof(data_t), this->_info, comm, &this->_data_ptr,
                     &this->_data_win);
    MPI_Win_allocate(this->_comm_size * sizeof(MPI_Aint), sizeof(MPI_Aint),
                     this->_info, comm, &this->_first_ptr, &this->_first_win);
    MPI_Win_allocate(this->_comm_size * sizeof(MPI_Aint), sizeof(MPI_Aint),
                     this->_info, comm, &this->_last_ptr, &this->_last_win);
    MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                     &this->_enqueuer_local_last_ptr,
                     &this->_enqueuer_local_last_win);
    this->_cached_data = (data_t **)malloc(sizeof(data_t *) * this->_comm_size);
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

  ~SpscDequeuer() {
    MPI_Win_unlock_all(_first_win);
    MPI_Win_unlock_all(_last_win);
    MPI_Win_unlock_all(_enqueuer_local_last_win);
    MPI_Win_unlock_all(_data_win);
    MPI_Win_free(&this->_data_win);
    MPI_Win_free(&this->_first_win);
    MPI_Win_free(&this->_last_win);
    MPI_Win_free(&this->_enqueuer_local_last_win);
    MPI_Info_free(&this->_info);
    for (int i = 0; i < this->_comm_size; ++i) {
      free(this->_cached_data[i]);
    }
    free(this->_cached_data);
    free(this->_cached_size);
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
      aread_async(output, this->_first_buf[enqueuer_rank] % this->_capacity,
                  enqueuer_rank, this->_data_win);
      int nreads = std::min(this->_batch_size,
                            this->_last_buf[enqueuer_rank] - new_first);
      this->_cached_size[enqueuer_rank] = nreads;
      for (int i = 0; i < nreads; ++i) {
        aread_async(this->_cached_data[enqueuer_rank] + nreads - i - 1,
                    (new_first + i) % this->_capacity, enqueuer_rank,
                    this->_data_win);
      }
      flush(enqueuer_rank, this->_data_win);
    }
    awrite_sync(&new_first, enqueuer_rank, this->_self_rank, this->_first_win);
    this->_first_buf[enqueuer_rank] = new_first;

    return true;
  }

  bool read_front(data_t *output, int enqueuer_rank) {
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
                    (this->_first_buf[enqueuer_rank] + i) % this->_capacity,
                    enqueuer_rank, this->_data_win);
      }
      flush(enqueuer_rank, this->_data_win);
    }
    *output = this->_cached_data[enqueuer_rank]
                                [this->_cached_size[enqueuer_rank] - 1];
    return true;
  }
};
