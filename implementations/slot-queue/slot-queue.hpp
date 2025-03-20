#pragma once

#include "../comm.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <vector>

template <typename T> class SlotEnqueuer {
private:
  typedef uint64_t timestamp_t;
  constexpr static timestamp_t MAX_TIMESTAMP = ~((uint64_t)0);

  struct data_t {
    T data;
    uint32_t timestamp;
  };

  MPI_Comm _comm;
  const MPI_Aint _self_rank;
  const MPI_Aint _enqueuer_order;
  const MPI_Aint _dequeuer_rank;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  class Spsc {
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
    MPI_Aint _last_buf;

  public:
    Spsc(MPI_Aint capacity, MPI_Aint self_rank, MPI_Aint dequeuer_rank,
         MPI_Comm comm)
        : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
          _capacity{capacity}, _first_buf{0}, _last_buf{0} {
      MPI_Info info;
      MPI_Info_create(&info);
      MPI_Info_set(info, "same_disp_unit", "true");

      MPI_Win_allocate(capacity * sizeof(data_t), sizeof(data_t), info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_first_ptr, &this->_first_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                       &this->_last_ptr, &this->_last_win);

      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      *this->_first_ptr = 0;
      *this->_last_ptr = 0;
      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Barrier(comm);
    }

    ~Spsc() {
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
    }

    bool enqueue(const data_t &data) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint new_last = this->_last_buf + 1;

      if (new_last - this->_first_buf > this->_capacity) {
        aread_sync(&this->_first_buf, 0, this->_self_rank, this->_first_win);
        if (new_last - this->_first_buf > this->_capacity) {
          MPI_Win_unlock_all(this->_first_win);
          MPI_Win_unlock_all(this->_last_win);
          MPI_Win_unlock_all(this->_data_win);
          return false;
        }
      }

      awrite_sync(&data, this->_last_buf % this->_capacity, this->_self_rank,
                  this->_data_win);
      awrite_async(&new_last, 0, this->_self_rank, this->_last_win);
      this->_last_buf = new_last;

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);

      return true;
    }

    bool enqueue(const std::vector<data_t> &data) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint new_last = this->_last_buf + data.size();

      if (new_last - this->_first_buf > this->_capacity) {
        aread_sync(&this->_first_buf, 0, this->_self_rank, this->_first_win);
        if (new_last - this->_first_buf > this->_capacity) {
          MPI_Win_unlock_all(this->_first_win);
          MPI_Win_unlock_all(this->_last_win);
          MPI_Win_unlock_all(this->_data_win);
          return false;
        }
      }

      if (this->_capacity - this->_last_buf % this->_capacity >= data.size()) {
        batch_awrite_sync(data.data(), data.size(),
                          this->_last_buf % this->_capacity, this->_self_rank,
                          this->_data_win);
      } else {
        batch_awrite_async(data.data(),
                           this->_capacity - this->_last_buf % this->_capacity,
                           this->_last_buf % this->_capacity, this->_self_rank,
                           this->_data_win);
        batch_awrite_async(
            data.data() + this->_capacity - this->_last_buf % this->_capacity,
            data.size() - this->_capacity + this->_last_buf % this->_capacity,
            0, this->_self_rank, this->_data_win);
      }

      awrite_async(&new_last, 0, this->_self_rank, this->_last_win);
      this->_last_buf = new_last;

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      return true;
    }

    bool read_front(uint32_t *output_timestamp) {
      if (this->_first_buf >= this->_last_buf) {
        return false;
      }
      aread_sync(&this->_first_buf, 0, this->_self_rank, this->_first_win);

      MPI_Win_lock_all(0, this->_data_win);

      data_t data;
      aread_async(&data, this->_first_buf % this->_capacity, this->_self_rank,
                  this->_data_win);

      MPI_Win_unlock_all(this->_data_win);
      *output_timestamp = data.timestamp;
      return true;
    }
  } _spsc;

public:
  SlotEnqueuer(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
               MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _enqueuer_order{self_rank > dequeuer_rank ? self_rank - 1 : self_rank},
        _spsc{capacity, self_rank, dequeuer_rank, comm} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_counter_ptr,
                     &this->_counter_win);

    MPI_Win_allocate(0, sizeof(timestamp_t), info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);

    MPI_Barrier(comm);
  }

  SlotEnqueuer(const SlotEnqueuer &) = delete;
  SlotEnqueuer &operator=(const SlotEnqueuer &) = delete;

  ~SlotEnqueuer() { MPI_Win_free(&this->_counter_win); }

  bool enqueue(const T &data) {}

  bool enqueue(const std::vector<T> &data) {}
};

template <typename T> class SlotDequeuer {
private:
  typedef uint64_t timestamp_t;
  constexpr static timestamp_t MAX_TIMESTAMP = ~((uint64_t)0);

  struct data_t {
    T data;
    uint32_t timestamp;
  };

  const MPI_Aint _self_rank;
  MPI_Comm _comm;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  class Spsc {
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

  public:
    Spsc(MPI_Aint capacity, MPI_Aint self_rank, MPI_Comm comm)
        : _self_rank{self_rank}, _capacity{capacity} {
      int size;
      MPI_Comm_size(comm, &size);
      _first_buf = std::vector<MPI_Aint>(size);
      _last_buf = std::vector<MPI_Aint>(size);

      MPI_Info info;
      MPI_Info_create(&info);
      MPI_Info_set(info, "same_disp_unit", "true");

      MPI_Win_allocate(0, sizeof(data_t), info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_first_ptr,
                       &this->_first_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_last_ptr,
                       &this->_last_win);
      MPI_Barrier(comm);
    }

    ~Spsc() {
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
    }

    bool dequeue(data_t *output, int enqueuer_rank) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint new_first = this->_first_buf[enqueuer_rank] + 1;
      if (new_first > this->_last_buf[enqueuer_rank]) {
        aread_sync(&this->_last_buf[enqueuer_rank], 0, enqueuer_rank,
                   this->_last_win);
        if (new_first > this->_last_buf[enqueuer_rank]) {
          MPI_Win_unlock_all(this->_first_win);
          MPI_Win_unlock_all(this->_last_win);
          MPI_Win_unlock_all(this->_data_win);
          return false;
        }
      }

      aread_sync(output, this->_first_buf[enqueuer_rank] % this->_capacity,
                 enqueuer_rank, this->_data_win);
      awrite_async(&new_first, 0, enqueuer_rank, this->_first_win);
      this->_first_buf[enqueuer_rank] = new_first;

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      return true;
    }

    bool read_front(uint32_t *output_timestamp, int enqueuer_rank) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      if (this->_first_buf[enqueuer_rank] >= this->_last_buf[enqueuer_rank]) {
        aread_sync(&this->_last_buf[enqueuer_rank], 0, enqueuer_rank,
                   this->_last_win);
        if (this->_first_buf[enqueuer_rank] >= this->_last_buf[enqueuer_rank]) {
          MPI_Win_unlock_all(this->_first_win);
          MPI_Win_unlock_all(this->_last_win);
          MPI_Win_unlock_all(this->_data_win);
          return false;
        }
      }

      data_t data;
      aread_async(&data, this->_first_buf[enqueuer_rank] % this->_capacity,
                  enqueuer_rank, this->_data_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      *output_timestamp = data.timestamp;
      return true;
    }
  } _spsc;

public:
  SlotDequeuer(MPI_Aint capacity, MPI_Aint dequeuer_rank, MPI_Aint self_rank,
               MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _spsc{capacity, self_rank, comm} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                     &this->_counter_ptr, &this->_counter_win);
    MPI_Win_lock_all(0, this->_counter_win);
    *this->_counter_ptr = 0;
    MPI_Win_unlock_all(this->_counter_win);

    int size;
    MPI_Comm_size(comm, &size);
    MPI_Win_allocate((size - 1) * sizeof(timestamp_t), sizeof(timestamp_t), info,
                     comm, &this->_min_timestamp_ptr,
                     &this->_min_timestamp_win);

    MPI_Barrier(comm);
  }

  SlotDequeuer(const SlotDequeuer &) = delete;
  SlotDequeuer &operator=(const SlotDequeuer &) = delete;
  ~SlotDequeuer() {
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
  }

  bool dequeue(T *output) {}
};
