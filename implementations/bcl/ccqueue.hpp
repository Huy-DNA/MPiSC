#pragma once

#include "../comm.hpp"
#include <algorithm>
#include <cstring>
#include <mpi.h>
#include <unistd.h>

class Backoff {
public:
  Backoff(size_t init_sleep = 1, size_t max_sleep = 1)
      : sleep_time_(init_sleep), max_sleep_(max_sleep),
        init_sleep_(init_sleep) {}

  void backoff() {
    usleep(sleep_time_);
    increase_backoff_impl_();
  }

  void increase_backoff_impl_() {
    sleep_time_ *= 2;
    sleep_time_ = std::min(sleep_time_, max_sleep_);
  }

  void reset() { sleep_time_ = init_sleep_; }

private:
  size_t sleep_time_;
  size_t max_sleep_;
  size_t init_sleep_;
};

struct CircularQueueAL {
  constexpr static int none = 0x0;
  constexpr static int enqueue = (0x1 << 0);
  constexpr static int dequeue = (0x1 << 1);
  constexpr static int enqueue_dequeue = (0x1 << 0) | (0x1 << 1);

  int val;

  CircularQueueAL(int val) : val(val) {}
  CircularQueueAL &operator=(const CircularQueueAL &) = default;

  operator int() const { return val; }

  CircularQueueAL &operator=(int val) {
    this->val = val;
    return *this;
  }

  bool operator==(int val) const { return this->val == val; }
};

template <typename T> class CCEnqueuer {
private:
  MPI_Win _reserved_head_win;
  MPI_Aint *_reserved_head_ptr;

  MPI_Win _head_win;
  MPI_Aint *_head_ptr;

  MPI_Win _reserved_tail_win;
  MPI_Aint *_reserved_tail_ptr;

  MPI_Win _tail_win;
  MPI_Aint *_tail_ptr;

  MPI_Win _data_win;
  MPI_Aint *_data_ptr;

  MPI_Aint _head_buf;

  const MPI_Aint _host;
  const MPI_Aint _self_rank;
  const MPI_Aint _capacity;

  MPI_Info _info;

public:
  CCEnqueuer(MPI_Aint capacity, MPI_Aint host, MPI_Aint self_rank,
             MPI_Comm comm)
      : _host{host}, _self_rank{self_rank}, _head_buf{0}, _capacity{capacity} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (host == self_rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_head_ptr, &this->_head_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_tail_ptr, &this->_tail_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_reserved_head_ptr, &this->_reserved_head_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_reserved_tail_ptr, &this->_reserved_tail_win);
      MPI_Win_allocate(capacity * sizeof(T), sizeof(T), this->_info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_reserved_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_reserved_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
      *this->_head_ptr = 0;
      *this->_tail_ptr = 0;
      *this->_reserved_head_ptr = 0;
      *this->_reserved_tail_ptr = 0;
      memset(this->_data_ptr, 0, capacity * sizeof(T));
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_head_ptr,
                       &this->_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_tail_ptr,
                       &this->_tail_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_reserved_head_ptr, &this->_reserved_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_reserved_tail_ptr, &this->_reserved_tail_win);
      MPI_Win_allocate(0, sizeof(T), this->_info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_reserved_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_reserved_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
    }
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Win_flush_all(this->_reserved_head_win);
    MPI_Win_flush_all(this->_reserved_tail_win);
    MPI_Win_flush_all(this->_data_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Win_flush_all(this->_reserved_head_win);
    MPI_Win_flush_all(this->_reserved_tail_win);
    MPI_Win_flush_all(this->_data_win);
  }

  ~CCEnqueuer() {
    MPI_Win_unlock_all(this->_head_win);
    MPI_Win_unlock_all(this->_tail_win);
    MPI_Win_unlock_all(this->_reserved_head_win);
    MPI_Win_unlock_all(this->_reserved_tail_win);
    MPI_Win_unlock_all(this->_data_win);
    MPI_Win_free(&this->_head_win);
    MPI_Win_free(&this->_tail_win);
    MPI_Win_free(&this->_reserved_head_win);
    MPI_Win_free(&this->_reserved_tail_win);
    MPI_Win_free(&this->_data_win);
    MPI_Info_free(&this->_info);
  }

  bool enqueue(const T &data,
               CircularQueueAL atomicity_level = CircularQueueAL::enqueue |
                                                 CircularQueueAL::dequeue) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    if (atomicity_level & CircularQueueAL::dequeue) {
      return this->_enqueue_atomic_impl(data);
    } else {
      return this->_enqueue_nonatomic_impl(data);
    }
  }

private:
  inline bool _enqueue_atomic_impl(const T &data, bool synchronized = false) {
    MPI_Aint old_tail;
    fetch_and_add_sync(&old_tail, 1, 0, this->_host, this->_tail_win);
    MPI_Aint new_tail = old_tail + 1;

    if (new_tail - this->_head_buf > this->_capacity) {
      if (synchronized) {
        Backoff backoff;
        while (new_tail - this->_head_buf > this->_capacity) {
          fetch_and_add_sync(&this->_head_buf, 0, 0, this->_host,
                             this->_reserved_head_win);
          if (new_tail - this->_head_buf > this->_capacity) {
            backoff.backoff();
          }
        }
      } else {
        fetch_and_add_sync(&this->_head_buf, 0, 0, this->_host,
                           this->_reserved_head_win);
      }
      if (new_tail - this->_head_buf > this->_capacity) {
        MPI_Aint _tmp;
        fetch_and_add_sync(&_tmp, -1, 0, this->_host, this->_tail_win);
        return false;
      }
    }
    write_sync(&data, old_tail % this->_capacity, this->_host, this->_data_win);
    MPI_Aint rv;
    Backoff backoff;
    do {
      compare_and_swap_sync(&old_tail, &new_tail, &rv, 0, this->_host,
                            this->_reserved_tail_win);
      if (rv != old_tail) {
        backoff.backoff();
      }
    } while (rv != old_tail);
    return true;
  }

  inline bool _enqueue_nonatomic_impl(const T &data) {
    MPI_Aint old_tail;
    fetch_and_add_sync(&old_tail, 1, 0, this->_host, this->_tail_win);
    MPI_Aint new_tail = old_tail + 1;

    if (new_tail - this->_head_buf > this->_capacity) {
      fetch_and_add_sync(&this->_head_buf, 0, 0, this->_host,
                         this->_reserved_head_win);
      if (new_tail - this->_head_buf > this->_capacity) {
        MPI_Aint _tmp;
        fetch_and_add_sync(&_tmp, -1, 0, this->_host, this->_tail_win);
        return false;
      }
    }

    awrite_async(&data, old_tail % this->_capacity, this->_host,
                 this->_data_win);
    MPI_Aint _tmp;
    fetch_and_add_sync(&_tmp, 1, 0, this->_host, this->_reserved_tail_win);
    return true;
  }
};

template <typename T> class CCDequeuer {
private:
  MPI_Win _reserved_head_win;
  MPI_Aint *_reserved_head_ptr;

  MPI_Win _head_win;
  MPI_Aint *_head_ptr;

  MPI_Win _reserved_tail_win;
  MPI_Aint *_reserved_tail_ptr;

  MPI_Win _tail_win;
  MPI_Aint *_tail_ptr;

  MPI_Win _data_win;
  MPI_Aint *_data_ptr;

  MPI_Win _flag_win;
  bool *_flag_ptr;

  MPI_Aint _head_buf;
  MPI_Aint _tail_buf;

  const MPI_Aint _host;
  const MPI_Aint _self_rank;
  const MPI_Aint _capacity;
  MPI_Info _info;

public:
  CCDequeuer(MPI_Aint capacity, MPI_Aint host, MPI_Aint self_rank,
             MPI_Comm comm)
      : _host{host}, _self_rank{self_rank}, _head_buf{0}, _capacity{capacity} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (host == self_rank) {
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_head_ptr, &this->_head_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_tail_ptr, &this->_tail_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_reserved_head_ptr, &this->_reserved_head_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_reserved_tail_ptr, &this->_reserved_tail_win);
      MPI_Win_allocate(capacity * sizeof(T), sizeof(T), this->_info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_reserved_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_reserved_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
      *this->_head_ptr = 0;
      *this->_tail_ptr = 0;
      *this->_reserved_head_ptr = 0;
      *this->_reserved_tail_ptr = 0;
      memset(this->_data_ptr, 0, capacity * sizeof(T));
    } else {
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_head_ptr,
                       &this->_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm, &this->_tail_ptr,
                       &this->_tail_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_reserved_head_ptr, &this->_reserved_head_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_reserved_tail_ptr, &this->_reserved_tail_win);
      MPI_Win_allocate(0, sizeof(T), this->_info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_reserved_head_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_reserved_tail_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_data_win);
    }
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Win_flush_all(this->_reserved_head_win);
    MPI_Win_flush_all(this->_reserved_tail_win);
    MPI_Win_flush_all(this->_data_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_head_win);
    MPI_Win_flush_all(this->_tail_win);
    MPI_Win_flush_all(this->_reserved_head_win);
    MPI_Win_flush_all(this->_reserved_tail_win);
    MPI_Win_flush_all(this->_data_win);
  }

  ~CCDequeuer() {
    MPI_Win_unlock_all(this->_head_win);
    MPI_Win_unlock_all(this->_tail_win);
    MPI_Win_unlock_all(this->_reserved_head_win);
    MPI_Win_unlock_all(this->_reserved_tail_win);
    MPI_Win_unlock_all(this->_data_win);
    MPI_Win_free(&this->_head_win);
    MPI_Win_free(&this->_tail_win);
    MPI_Win_free(&this->_reserved_head_win);
    MPI_Win_free(&this->_reserved_tail_win);
    MPI_Win_free(&this->_data_win);
    MPI_Info_free(&this->_info);
  }

  bool dequeue(T *output,
               CircularQueueAL atomicity_level = CircularQueueAL::enqueue |
                                                 CircularQueueAL::dequeue) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    if (atomicity_level & CircularQueueAL::enqueue) {
      return this->_dequeue_atomic_impl(output);
    } else if (atomicity_level & CircularQueueAL::dequeue) {
      return this->_dequeue_nonatomic_impl(output);
    } else if (atomicity_level == CircularQueueAL::none) {
      return this->_local_nonatomic_dequeue(output);
    }
    return false;
  }

private:
  inline bool _dequeue_atomic_impl(T *output) {
    MPI_Aint old_head;
    fetch_and_add_sync(&old_head, 1, 0, this->_host, this->_head_win);
    MPI_Aint new_head = old_head + 1;

    if (new_head > this->_tail_buf) {
      fetch_and_add_sync(&this->_tail_buf, 0, 0, this->_host,
                         this->_reserved_tail_win);
      if (new_head > this->_tail_buf) {
        MPI_Aint _tmp;
        fetch_and_add_sync(&_tmp, -1, 0, this->_host, this->_head_win);
        return false;
      }
    }

    aread_sync(output, old_head % this->_capacity, this->_host,
               this->_data_win);

    MPI_Aint rv;
    size_t backoff_value;
    if (this->_self_rank == this->_host) {
      backoff_value = 100;
    } else {
      backoff_value = 100;
    }
    Backoff backoff{1, backoff_value};
    do {
      compare_and_swap_sync(&old_head, &new_head, &rv, 0, this->_host,
                            this->_reserved_head_win);
      if (rv != old_head) {
        backoff.backoff();
      }
    } while (rv != old_head);
    return true;
  }

  inline bool _dequeue_nonatomic_impl(T *output) {
    MPI_Aint old_head;
    fetch_and_add_sync(&old_head, 1, 0, this->_host, this->_head_win);
    MPI_Aint new_head = old_head + 1;

    if (new_head > this->_tail_buf) {
      aread_sync(&this->_tail_buf, 0, this->_host, this->_tail_win);
      if (new_head > this->_tail_buf) {
        MPI_Aint _tmp;
        fetch_and_add_sync(&_tmp, -1, 0, this->_host, this->_head_win);
        return false;
      }
    }

    aread_async(output, old_head % this->_capacity, this->_host,
                this->_data_win);
    MPI_Aint _tmp;
    fetch_and_add_sync(&_tmp, 1, 0, this->_host, this->_reserved_head_win);
    return true;
  }

  inline bool _local_nonatomic_dequeue(T *output) {
    if (this->_self_rank != this->_host) {
      return false;
    }
    if (*this->_head_ptr + 1 > *this->_tail_ptr) {
      return false;
    }
    *output = this->_data_ptr[*this->_head_ptr % this->_capacity];
    *this->_head_ptr += 1;
    return true;
  }
};
