#pragma once

#include "../comm.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <vector>

template <typename T> class LTEnqueuer {
private:
  struct tree_node_t {
    int32_t rank;
    uint32_t tag;
  };
  constexpr static int32_t DUMMY_RANK = ~((uint32_t)0);

  struct timestamp_t {
    uint32_t timestamp;
    uint32_t tag;
  };
  constexpr static uint32_t MAX_TIMESTAMP = ~((uint32_t)0);

  struct data_t {
    T data;
    uint32_t timestamp;
  };

  MPI_Comm _comm;
  int _self_rank;
  int _enqueuer_order;
  int _dequeuer_rank;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  MPI_Win _tree_win;
  tree_node_t *_tree_ptr;

  class Spsc {
    int _self_rank;
    int _dequeuer_rank;

    MPI_Aint _size;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;
    MPI_Aint _first_buf;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;
    MPI_Aint _last_buf;

  public:
    Spsc(MPI_Comm comm, MPI_Aint size, int self_rank, int dequeuer_rank)
        : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank}, _size{size},
          _first_buf{0} {
      MPI_Info info;
      MPI_Info_create(&info);
      MPI_Info_set(info, "same_disp_unit", "true");

      MPI_Win_allocate(size * sizeof(data_t), sizeof(data_t), info, comm,
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

      aread_sync(&this->_last_buf, 0, this->_self_rank, this->_last_win);
      MPI_Aint new_last = this->_last_buf + 1;

      if (new_last - this->_first_buf > this->_size) {
        aread_sync(&this->_first_buf, 0, this->_self_rank, this->_first_win);
        if (new_last - this->_first_buf > this->_size) {
          MPI_Win_unlock_all(this->_first_win);
          MPI_Win_unlock_all(this->_last_win);
          MPI_Win_unlock_all(this->_data_win);
          return false;
        }
      }

      write_sync(&data, this->_last_buf % this->_size, this->_self_rank,
                 this->_data_win);
      awrite_async(&new_last, 0, this->_self_rank, this->_last_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);

      return true;
    }

    bool read_front(uint32_t *output_timestamp) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      if (this->_first_buf >= this->_last_buf) {
        aread_sync(&this->_first_buf, 0, this->_self_rank, this->_first_win);
        if (this->_first_buf >= this->_last_buf) {
          MPI_Win_unlock_all(this->_first_win);
          MPI_Win_unlock_all(this->_last_win);
          MPI_Win_unlock_all(this->_data_win);
          return false;
        }
      }
      data_t data;
      aread_async(&data, this->_first_buf % this->_size, this->_self_rank,
                  this->_data_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      *output_timestamp = data.timestamp;
      return true;
    }
  } _spsc;

  int _get_number_of_enqueuers() const {
    int number_processes;
    MPI_Comm_size(this->_comm, &number_processes);

    return number_processes - 1;
  }

  int _get_tree_size() const { return 2 * this->_get_number_of_enqueuers(); }

  int _get_parent_index(int index) const {
    if (index == 0) {
      return -1;
    }
    return (index - 1) / 2;
  }

  int _get_self_index() const {
    return this->_get_number_of_enqueuers() + this->_enqueuer_order;
  }

  std::vector<int> _get_children_indexes(int index) const {
    int left_child = index * 2 + 1;
    int right_child = index * 2 + 2;
    std::vector<int> res;
    if (left_child >= this->_get_tree_size()) {
      return res;
    }
    res.push_back(left_child);
    if (right_child >= this->_get_tree_size()) {
      return res;
    }
    res.push_back(right_child);
    return res;
  }

  void _propagate() {
    if (!this->_refresh_self_node()) {
      this->_refresh_self_node();
    }
    int current_index = this->_get_self_index();
    do {
      current_index = this->_get_parent_index(current_index);
      if (!this->_refresh(current_index)) {
        this->_refresh(current_index);
      }
    } while (current_index != 0);
  }

  bool _refresh_self_node() {
    bool res;
    int self_index = this->_get_self_index();
    tree_node_t self_node;
    timestamp_t min_timestamp;
    MPI_Win_lock_all(0, this->_min_timestamp_win);
    aread_async(&min_timestamp, 0, this->_self_rank, this->_min_timestamp_win);
    MPI_Win_unlock_all(this->_min_timestamp_win);

    MPI_Win_lock_all(0, this->_tree_win);
    aread_sync(&self_node, self_index, this->_dequeuer_rank, this->_tree_win);
    if (min_timestamp.timestamp == MAX_TIMESTAMP) {
      const tree_node_t new_node = {DUMMY_RANK, self_node.tag + 1};
      tree_node_t result_node;
      compare_and_swap_sync(&self_node, &new_node, &result_node, self_index,
                            this->_dequeuer_rank, this->_tree_win);
      res = result_node.rank == self_node.rank &&
            result_node.tag == self_node.tag;
    } else {
      const tree_node_t new_node = {this->_self_rank, self_node.tag + 1};
      tree_node_t result_node;
      compare_and_swap_sync(&self_node, &new_node, &result_node, self_index,
                            this->_dequeuer_rank, this->_tree_win);
      res = result_node.rank == self_node.rank &&
            result_node.tag == self_node.tag;
    }
    MPI_Win_unlock_all(this->_tree_win);
    return res;
  }

  bool _refresh_timestamp() {
    bool res;

    uint32_t min_timestamp;
    bool min_timestamp_succeeded = this->_spsc.read_front(&min_timestamp);

    MPI_Win_lock_all(0, this->_min_timestamp_win);
    timestamp_t current_timestamp;
    aread_sync(&current_timestamp, 0, this->_self_rank,
               this->_min_timestamp_win);
    if (!min_timestamp_succeeded) {
      const timestamp_t new_timestamp = {MAX_TIMESTAMP,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      compare_and_swap_sync(&current_timestamp, &new_timestamp,
                            &result_timestamp, 0, this->_self_rank,
                            this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            result_timestamp.timestamp == current_timestamp.timestamp;
    } else {

      const timestamp_t new_timestamp = {min_timestamp,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      compare_and_swap_sync(&current_timestamp, &new_timestamp,
                            &result_timestamp, 0, this->_self_rank,
                            this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            result_timestamp.timestamp == current_timestamp.timestamp;
    }
    MPI_Win_unlock_all(this->_min_timestamp_win);
    return res;
  }

  bool _refresh(int current_index) {
    tree_node_t current_node;
    uint32_t min_timestamp = MAX_TIMESTAMP;
    int32_t min_timestamp_rank = DUMMY_RANK;
    MPI_Win_lock_all(0, this->_tree_win);
    MPI_Win_lock_all(0, this->_min_timestamp_win);
    aread_sync(&current_node, current_index, this->_dequeuer_rank,
               this->_tree_win);
    for (const int child_index : this->_get_children_indexes(current_index)) {
      tree_node_t child_node;
      aread_sync(&child_node, child_index, this->_dequeuer_rank,
                 this->_tree_win);
      if (child_node.rank == DUMMY_RANK) {
        continue;
      }
      timestamp_t child_timestamp;
      aread_sync(&child_timestamp, 0, child_node.rank,
                 this->_min_timestamp_win);
      if (child_timestamp.timestamp < min_timestamp) {
        min_timestamp = child_timestamp.timestamp;
        min_timestamp_rank = child_node.rank;
      }
    }
    MPI_Win_unlock_all(this->_min_timestamp_win);
    const tree_node_t new_node = {min_timestamp_rank, current_node.tag + 1};
    tree_node_t result_node;
    compare_and_swap_sync(&current_node, &new_node, &result_node, current_index,
                          this->_dequeuer_rank, this->_tree_win);
    MPI_Win_unlock_all(this->_tree_win);
    return result_node.tag == current_node.tag &&
           result_node.rank == current_node.rank;
  }

public:
  LTEnqueuer(MPI_Comm comm, MPI_Aint size, int self_rank, int dequeuer_rank)
      : _comm{comm}, _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank},
        _enqueuer_order{self_rank > dequeuer_rank ? self_rank - 1 : self_rank},
        _spsc{comm, size, self_rank, dequeuer_rank} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(0, sizeof(uint32_t), info, comm, &this->_counter_ptr,
                     &this->_counter_win);

    MPI_Win_allocate(sizeof(timestamp_t), sizeof(timestamp_t), info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);

    MPI_Win_lock_all(0, this->_min_timestamp_win);
    const timestamp_t start_timestamp = {MAX_TIMESTAMP, 0};
    awrite_async(&start_timestamp, 0, this->_self_rank,
                 this->_min_timestamp_win);
    MPI_Win_unlock_all(this->_min_timestamp_win);

    MPI_Win_allocate(0, sizeof(tree_node_t), info, comm, &this->_tree_ptr,
                     &this->_tree_win);

    MPI_Barrier(comm);
  }

  LTEnqueuer(const LTEnqueuer &) = delete;
  LTEnqueuer &operator=(const LTEnqueuer &) = delete;

  ~LTEnqueuer() {
    MPI_Win_free(&this->_tree_win);
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
  }

  bool enqueue(const T &data) {
    MPI_Win_lock_all(0, this->_counter_win);
    uint32_t timestamp;
    fetch_and_add_sync(&timestamp, 1, 0, this->_dequeuer_rank,
                       this->_counter_win);
    MPI_Win_unlock_all(this->_counter_win);
    if (!this->_spsc.enqueue({data, timestamp})) {
      return false;
    }
    if (!this->_refresh_timestamp()) {
      this->_refresh_timestamp();
    }
    this->_propagate();
    return true;
  }
};

template <typename T> class LTDequeuer {
private:
  struct tree_node_t {
    int32_t rank;
    uint32_t tag;
  };

  constexpr static int32_t DUMMY_RANK = ~((uint32_t)0);

  struct timestamp_t {
    uint32_t timestamp;
    uint32_t tag;
  };
  constexpr static uint32_t MAX_TIMESTAMP = ~((uint32_t)0);

  struct data_t {
    T data;
    uint32_t timestamp;
  };

  int _self_rank;
  MPI_Comm _comm;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  MPI_Win _tree_win;
  tree_node_t *_tree_ptr;

  class Spsc {
    MPI_Aint _self_rank;

    MPI_Aint _size;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;
    MPI_Aint _first_buf;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;
    MPI_Aint _last_buf;

  public:
    Spsc(MPI_Comm comm, MPI_Aint size, int self_rank)
        : _self_rank{self_rank}, _size{size}, _last_buf{0} {
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

      aread_sync(&this->_first_buf, 0, enqueuer_rank, this->_first_win);

      MPI_Aint new_first = this->_first_buf + 1;
      if (new_first > this->_last_buf) {
        aread_sync(&this->_last_buf, 0, enqueuer_rank, this->_last_win);
        if (new_first > this->_last_buf) {
          output = NULL;
          MPI_Win_unlock_all(this->_first_win);
          MPI_Win_unlock_all(this->_last_win);
          MPI_Win_unlock_all(this->_data_win);
          return false;
        }
      }

      aread_sync(output, this->_first_buf % this->_size, enqueuer_rank,
                 this->_data_win);
      awrite_async(&new_first, 0, enqueuer_rank, this->_first_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      return true;
    }

    bool read_front(uint32_t *output_timestamp, int enqueuer_rank) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      if (this->_first_buf >= this->_last_buf) {
        aread_sync(&this->_last_buf, 0, enqueuer_rank, this->_last_win);
        if (this->_first_buf >= this->_last_buf) {
          MPI_Win_unlock_all(this->_first_win);
          MPI_Win_unlock_all(this->_last_win);
          MPI_Win_unlock_all(this->_data_win);
          return false;
        }
      }

      data_t data;
      aread_async(&data, this->_first_buf % this->_size, this->_self_rank,
                  this->_data_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      *output_timestamp = data.timestamp;
      return true;
    }
  } _spsc;

  int _get_number_of_enqueuers() const {
    int number_processes;
    MPI_Comm_size(this->_comm, &number_processes);

    return number_processes - 1;
  }

  int _get_tree_size() const { return 2 * this->_get_number_of_enqueuers(); }

  int _get_parent_index(int index) const {
    if (index == 0) {
      return -1;
    }
    return (index - 1) / 2;
  }

  int _get_enqueuer_index(int rank) const {
    return this->_get_number_of_enqueuers() +
           (rank > this->_self_rank ? rank - 1 : rank);
  }

  std::vector<int> _get_children_indexes(int index) const {
    int left_child = index * 2 + 1;
    int right_child = index * 2 + 2;
    std::vector<int> res;
    if (left_child >= this->_get_tree_size()) {
      return res;
    }
    res.push_back(left_child);
    if (right_child >= this->_get_tree_size()) {
      return res;
    }
    res.push_back(right_child);
    return res;
  }

  bool _refresh_timestamp(int enqueuer_rank) {
    bool res;

    uint32_t min_timestamp;
    bool min_timestamp_succeeded =
        this->_spsc.read_front(&min_timestamp, enqueuer_rank);

    MPI_Win_lock_all(0, this->_min_timestamp_win);
    timestamp_t current_timestamp;
    aread_sync(&current_timestamp, 0, enqueuer_rank, this->_min_timestamp_win);

    if (!min_timestamp_succeeded) {
      const timestamp_t new_timestamp = {MAX_TIMESTAMP,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      compare_and_swap_sync(&current_timestamp, &new_timestamp,
                            &result_timestamp, 0, enqueuer_rank,
                            this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            result_timestamp.timestamp == current_timestamp.timestamp;
    } else {
      const timestamp_t new_timestamp = {min_timestamp,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      compare_and_swap_sync(&current_timestamp, &new_timestamp,
                            &result_timestamp, 0, enqueuer_rank,
                            this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            current_timestamp.timestamp == result_timestamp.timestamp;
    }
    MPI_Win_unlock_all(this->_min_timestamp_win);
    return res;
  }

  bool _refresh_self_node(int enqueuer_rank) {
    bool res;
    int self_index = this->_get_enqueuer_index(enqueuer_rank);
    tree_node_t self_node;
    timestamp_t min_timestamp;
    MPI_Win_lock_all(0, this->_min_timestamp_win);
    aread_async(&min_timestamp, 0, this->_self_rank, this->_min_timestamp_win);
    MPI_Win_unlock_all(this->_min_timestamp_win);

    MPI_Win_lock_all(0, this->_tree_win);
    aread_sync(&self_node, self_index, this->_self_rank, this->_tree_win);
    if (min_timestamp.timestamp == MAX_TIMESTAMP) {
      const tree_node_t new_node = {DUMMY_RANK, self_node.tag + 1};
      tree_node_t result_node;
      compare_and_swap_sync(&self_node, &new_node, &result_node, self_index,
                            this->_self_rank, this->_tree_win);
      res = result_node.tag == self_node.tag &&
            result_node.rank == self_node.rank;
    } else {
      const tree_node_t new_node = {enqueuer_rank, self_node.tag + 1};
      tree_node_t result_node;
      compare_and_swap_sync(&self_node, &new_node, &result_node, self_index,
                            this->_self_rank, this->_tree_win);
      res = result_node.tag == self_node.tag &&
            result_node.rank == self_node.rank;
    }
    MPI_Win_unlock_all(this->_tree_win);
    return res;
  }

  bool _refresh(int current_index) {
    tree_node_t current_node;
    uint32_t min_timestamp = MAX_TIMESTAMP;
    int32_t min_timestamp_rank = DUMMY_RANK;
    MPI_Win_lock_all(0, this->_tree_win);
    aread_sync(&current_node, current_index, this->_self_rank, this->_tree_win);
    for (const int child_index : this->_get_children_indexes(current_index)) {
      tree_node_t child_node;
      aread_sync(&child_node, child_index, this->_self_rank, this->_tree_win);
      if (child_node.rank == DUMMY_RANK) {
        continue;
      }
      MPI_Win_lock_all(0, this->_min_timestamp_win);
      timestamp_t child_timestamp;
      aread_sync(&child_timestamp, 0, child_node.rank,
                 this->_min_timestamp_win);
      MPI_Win_unlock_all(this->_min_timestamp_win);
      if (child_timestamp.timestamp < min_timestamp) {
        min_timestamp = child_timestamp.timestamp;
        min_timestamp_rank = child_node.rank;
      }
    }
    const tree_node_t new_node = {min_timestamp_rank, current_node.tag + 1};
    tree_node_t result_node;
    compare_and_swap_sync(&current_node, &new_node, &result_node, current_index,
                          this->_self_rank, this->_tree_win);
    MPI_Win_unlock_all(this->_tree_win);
    return result_node.tag == current_node.tag &&
           result_node.rank == current_node.rank;
  }

  void _propagate(int enqueuer_rank) {
    if (!this->_refresh_self_node(enqueuer_rank)) {
      this->_refresh_self_node(enqueuer_rank);
    }
    int current_index = this->_get_enqueuer_index(enqueuer_rank);
    do {
      current_index = this->_get_parent_index(current_index);
      if (!this->_refresh(current_index)) {
        this->_refresh(current_index);
      }
    } while (current_index != 0);
  }

public:
  LTDequeuer(MPI_Comm comm, MPI_Aint size, int self_rank)
      : _comm{comm}, _self_rank{self_rank}, _spsc{comm, size, self_rank} {
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(sizeof(uint32_t), sizeof(uint32_t), info, comm,
                     &this->_counter_ptr, &this->_counter_win);
    MPI_Win_lock_all(0, this->_counter_win);
    *this->_counter_ptr = 0;
    MPI_Win_unlock_all(this->_counter_win);

    MPI_Win_allocate(0, sizeof(timestamp_t), info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);

    MPI_Win_allocate(this->_get_tree_size() * sizeof(tree_node_t),
                     sizeof(tree_node_t), info, comm, &this->_tree_ptr,
                     &this->_tree_win);

    MPI_Win_lock_all(0, this->_tree_win);
    for (int i = 0; i < this->_get_tree_size(); ++i) {
      this->_tree_ptr[i] = {DUMMY_RANK, 0};
    }
    MPI_Win_unlock_all(this->_tree_win);

    MPI_Barrier(comm);
  }
  LTDequeuer(const LTDequeuer &) = delete;
  LTDequeuer &operator=(const LTDequeuer &) = delete;
  ~LTDequeuer() {
    MPI_Win_free(&this->_tree_win);
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
  }

  bool dequeue(T *output) {
    MPI_Win_lock_all(0, this->_tree_win);
    tree_node_t root;
    aread_async(&root, 0, this->_self_rank, this->_tree_win);
    MPI_Win_unlock_all(this->_tree_win);

    if (root.rank == DUMMY_RANK) {
      output = NULL;
      return false;
    }
    data_t spsc_output;
    if (!this->_spsc.dequeue(&spsc_output, root.rank)) {
      return false;
    }
    if (!this->_refresh_timestamp(root.rank)) {
      this->_refresh_timestamp(root.rank);
    }
    this->_propagate(root.rank);
    *output = spsc_output.data;
    return true;
  }
};
