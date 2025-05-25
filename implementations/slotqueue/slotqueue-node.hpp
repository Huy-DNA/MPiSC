#pragma once

#include "../lib/comm.hpp"
#include "../lib/distributed-counters/faa.hpp"
#include "../lib/sleep.hpp"
#include "../lib/spsc.hpp"
#include <atomic>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <mpi_proto.h>
#include <vector>

template <typename T> class SlotNodeEnqueuer {
private:
  typedef uint64_t timestamp_t;
  constexpr static timestamp_t MAX_TIMESTAMP = ~((uint64_t)0);
  struct data_t {
    T data;
    uint64_t timestamp;
  };

  MPI_Info _info;

private:
  MPI_Comm _sm_comm;
  int _sm_size;

  MPI_Win _start_counter_win;
  std::atomic<uint64_t> *_start_counter_ptr;

  MPI_Win _self_start_counter_win;
  std::atomic<uint64_t> *_self_start_counter_ptr;

  MPI_Win _self_remote_counter_win;
  std::atomic<uint64_t> *_self_remote_counter_ptr;

  timestamp_t _obtain_timestamp() {
    MPI_Aint size = 1;
    int disp_unit = sizeof(std::atomic<uint64_t>);
    std::atomic<uint64_t> *shared_start_baseptr;
    MPI_Win_shared_query(this->_start_counter_win, 0, &size, &disp_unit,
                         &shared_start_baseptr);
    timestamp_t self_start = shared_start_baseptr->fetch_add(1);
    this->_self_start_counter_ptr->store(self_start);

    timestamp_t self_counter = MAX_TIMESTAMP;
    for (int i = 0; i < this->_sm_size; ++i) {
      std::atomic<uint64_t> *start_baseptr;
      MPI_Win_shared_query(this->_self_start_counter_win, i, &size, &disp_unit,
                           &start_baseptr);
      if (self_start < start_baseptr->load()) {
        std::atomic<uint64_t> *self_baseptr;
        MPI_Win_shared_query(this->_self_remote_counter_win, i, &size,
                             &disp_unit, &self_baseptr);
        timestamp_t counter = self_baseptr->load();
        if (counter == MAX_TIMESTAMP) {
          for (int retries = 0; retries < 300; ++retries) {
            spin(10);
            timestamp_t counter = self_baseptr->load();
            if (counter != MAX_TIMESTAMP) {
              self_counter = counter;
              break;
            }
          }
        } else {
          self_counter = counter;
        }
      }
    }
    if (self_counter == MAX_TIMESTAMP) {
      self_counter = this->_counter.get_and_increment();
    }
    this->_self_remote_counter_ptr->store(self_counter);
    return self_counter;
  }

private:
  MPI_Comm _comm;
  const MPI_Aint _self_rank;
  const MPI_Aint _enqueuer_order;
  const MPI_Aint _dequeuer_rank;

  FaaCounter _counter;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  SpscEnqueuer<data_t> _spsc;

  bool _refreshEnqueue(timestamp_t ts) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    data_t front;
    // avoid possibily redundant remote read below
    timestamp_t new_timestamp;
    if (!this->_spsc.read_front(&front)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
    }
    if (new_timestamp != ts) {
      return true;
    }

    timestamp_t old_timestamp;
    fetch_and_add_sync(&old_timestamp, 0, this->_enqueuer_order,
                       this->_dequeuer_rank, this->_min_timestamp_win);
    if (!this->_spsc.read_front(&front)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
    }
    if (new_timestamp != ts) {
      return true;
    }
    timestamp_t result;
    compare_and_swap_sync(&old_timestamp, &new_timestamp, &result,
                          this->_enqueuer_order, this->_dequeuer_rank,
                          this->_min_timestamp_win);
    return result == old_timestamp;
  }

public:
  SlotNodeEnqueuer(MPI_Aint capacity_per_node, MPI_Aint dequeuer_rank,
                   MPI_Aint self_rank, MPI_Comm comm)
      : _comm{comm}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _enqueuer_order{self_rank > dequeuer_rank ? self_rank - 1 : self_rank},
        _spsc{capacity_per_node, self_rank, dequeuer_rank, comm},
        _counter{dequeuer_rank, dequeuer_rank, comm} {
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");
    MPI_Comm_split_type(this->_comm, MPI_COMM_TYPE_SHARED, 0, MPI_INFO_NULL,
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

    MPI_Win_allocate(0, sizeof(timestamp_t), this->_info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_min_timestamp_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_self_remote_counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_start_counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_self_start_counter_win);
    *this->_self_remote_counter_ptr = 0;
    *this->_start_counter_ptr = 0;
    *this->_self_start_counter_ptr = 0;

    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Win_flush_all(this->_self_remote_counter_win);
    MPI_Win_flush_all(this->_start_counter_win);
    MPI_Win_flush_all(this->_self_start_counter_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Win_flush_all(this->_self_remote_counter_win);
    MPI_Win_flush_all(this->_start_counter_win);
    MPI_Win_flush_all(this->_self_start_counter_win);
  }

  SlotNodeEnqueuer(const SlotNodeEnqueuer &) = delete;
  SlotNodeEnqueuer &operator=(const SlotNodeEnqueuer &) = delete;

  ~SlotNodeEnqueuer() {
    MPI_Win_unlock_all(_min_timestamp_win);
    MPI_Win_unlock_all(_self_remote_counter_win);
    MPI_Win_unlock_all(_start_counter_win);
    MPI_Win_unlock_all(_self_start_counter_win);
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Win_free(&this->_self_remote_counter_win);
    MPI_Win_free(&this->_start_counter_win);
    MPI_Win_free(&this->_self_start_counter_win);
    MPI_Comm_free(&this->_sm_comm);
    MPI_Info_free(&this->_info);
  }

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    this->_self_remote_counter_ptr->store(MAX_TIMESTAMP);
    timestamp_t counter = this->_obtain_timestamp();
    data_t value{data, counter};
    bool res = this->_spsc.enqueue(value);
    if (!res) {
      return false;
    }
    if (!this->_refreshEnqueue(counter)) {
      this->_refreshEnqueue(counter);
    }
    return res;
  }

  bool enqueue(const std::vector<T> &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    if (data.size() == 0) {
      return true;
    }

    timestamp_t counter = this->_counter.get_and_increment();
    std::vector<data_t> timestamped_data;
    for (const T &datum : data) {
      timestamped_data.push_back(data_t{datum, counter});
    }
    bool res = this->_spsc.enqueue(timestamped_data);
    if (!res) {
      return false;
    }
    if (!this->_refreshEnqueue(counter)) {
      this->_refreshEnqueue(counter);
    }
    return res;
  }
};

template <typename T> class SlotNodeDequeuer {
private:
  typedef uint64_t timestamp_t;
  constexpr static timestamp_t MAX_TIMESTAMP = ~((uint64_t)0);
  constexpr static MPI_Aint DUMMY_RANK = ~((MPI_Aint)0);

  struct data_t {
    T data;
    uint64_t timestamp;
  };
  MPI_Info _info;

private:
  MPI_Comm _sm_comm;

  MPI_Win _start_counter_win;
  std::atomic<uint64_t> *_start_counter_ptr;

  MPI_Win _self_remote_counter_win;
  std::atomic<uint64_t> *_self_remote_counter_ptr;

  MPI_Win _self_start_counter_win;
  std::atomic<uint64_t> *_self_start_counter_ptr;

private:
  const MPI_Aint _self_rank;
  MPI_Comm _comm;
  MPI_Aint _number_of_enqueuers;

  FaaCounter _counter;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;
  timestamp_t *_min_timestamp_buf;

  SpscDequeuer<data_t> _spsc;

  MPI_Aint _readMinimumRank() {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    MPI_Aint order = DUMMY_RANK;
    timestamp_t min_timestamp = MAX_TIMESTAMP;

    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      aread_async(&this->_min_timestamp_buf[i], i, this->_self_rank,
                  this->_min_timestamp_win);
    }
    flush(this->_self_rank, this->_min_timestamp_win);
    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      timestamp_t timestamp = this->_min_timestamp_buf[i];
      if (timestamp < min_timestamp) {
        order = i;
        min_timestamp = timestamp;
      }
    }
    if (order == DUMMY_RANK) {
      return DUMMY_RANK;
    }
    for (int i = 0; i < order; ++i) {
      aread_async(&this->_min_timestamp_buf[i], i, this->_self_rank,
                  this->_min_timestamp_win);
    }
    flush(this->_self_rank, this->_min_timestamp_win);
    for (int i = 0; i < order; ++i) {
      timestamp_t timestamp = this->_min_timestamp_buf[i];
      if (timestamp < min_timestamp) {
        order = i;
        min_timestamp = timestamp;
      }
    }
    return order >= this->_self_rank ? order + 1 : order;
  }

  bool _refreshDequeue(MPI_Aint rank) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    MPI_Aint enqueuer_order = this->_get_enqueuer_order(rank);
    timestamp_t old_timestamp;
    fetch_and_add_sync(&old_timestamp, 0, enqueuer_order, this->_self_rank,
                       this->_min_timestamp_win);
    data_t front;
    timestamp_t new_timestamp;
    if (!this->_spsc.read_front(&front, rank)) {
      new_timestamp = MAX_TIMESTAMP;
    } else {
      new_timestamp = front.timestamp;
    }
    timestamp_t result;
    compare_and_swap_sync(&old_timestamp, &new_timestamp, &result,
                          enqueuer_order, this->_self_rank,
                          this->_min_timestamp_win);
    return result == old_timestamp;
  }

  int _get_enqueuer_order(MPI_Aint rank) const {
    return rank > this->_self_rank ? rank - 1 : rank;
  }

public:
  SlotNodeDequeuer(MPI_Aint capacity_per_node, MPI_Aint dequeuer_rank,
                   MPI_Aint self_rank, MPI_Comm comm, MPI_Aint batch_size = 10)
      : _comm{comm}, _self_rank{self_rank},
        _spsc{capacity_per_node, self_rank, comm, batch_size},
        _counter{dequeuer_rank, dequeuer_rank, comm} {
    int size;
    MPI_Comm_size(comm, &size);
    this->_number_of_enqueuers = size - 1;

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    MPI_Comm_split_type(this->_comm, MPI_COMM_TYPE_SHARED, 0, MPI_INFO_NULL,
                        &this->_sm_comm);

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

    MPI_Win_allocate(this->_number_of_enqueuers * sizeof(timestamp_t),
                     sizeof(timestamp_t), this->_info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_min_timestamp_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_self_remote_counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_start_counter_win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_self_start_counter_win);

    for (int i = 0; i < this->_number_of_enqueuers; ++i) {
      this->_min_timestamp_ptr[i] = MAX_TIMESTAMP;
    }
    this->_min_timestamp_buf = new timestamp_t[this->_number_of_enqueuers];
    *this->_self_remote_counter_ptr = 0;
    *this->_start_counter_ptr = 0;
    *this->_self_start_counter_ptr = 0;

    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Win_flush_all(this->_self_remote_counter_win);
    MPI_Win_flush_all(this->_start_counter_win);
    MPI_Win_flush_all(this->_self_start_counter_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Win_flush_all(this->_self_remote_counter_win);
    MPI_Win_flush_all(this->_start_counter_win);
    MPI_Win_flush_all(this->_self_start_counter_win);
  }

  SlotNodeDequeuer(const SlotNodeDequeuer &) = delete;
  SlotNodeDequeuer &operator=(const SlotNodeDequeuer &) = delete;
  ~SlotNodeDequeuer() {
    MPI_Win_unlock_all(_min_timestamp_win);
    MPI_Win_unlock_all(_self_remote_counter_win);
    MPI_Win_unlock_all(_start_counter_win);
    MPI_Win_unlock_all(_self_start_counter_win);
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Win_free(&this->_self_remote_counter_win);
    MPI_Win_free(&this->_start_counter_win);
    MPI_Win_free(&this->_self_start_counter_win);
    delete[] this->_min_timestamp_buf;
    MPI_Comm_free(&this->_sm_comm);
    MPI_Info_free(&this->_info);
  }

  bool dequeue(T *output) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    MPI_Aint rank = this->_readMinimumRank();
    if (rank == DUMMY_RANK) {
      return false;
    }
    data_t output_data;
    bool res = this->_spsc.dequeue(&output_data, rank);
    if (!res) {
      return false;
    }
    *output = output_data.data;
    if (!this->_refreshDequeue(rank)) {
      this->_refreshDequeue(rank);
    }
    return true;
  }
};
