#pragma once

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
  MPI_Datatype _tree_node_type;

  struct timestamp_t {
    uint32_t timestamp;
    uint32_t tag;
  };
  constexpr static uint32_t MAX_TIMESTAMP = ~((uint32_t)0);
  MPI_Datatype _timestamp_type;

  struct data_t {
    T data;
    uint32_t timestamp;
  };

  MPI_Datatype _t_type;

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
    MPI_Datatype _data_type;
    int _self_rank;
    int _dequeuer_rank;

    MPI_Aint _size;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;

    void init_data_type(MPI_Datatype original_type) {
      int blocklengths[] = {1, 1};
      MPI_Datatype types[] = {original_type, MPI_UINT32_T};
      MPI_Aint offsets[2];
      offsets[0] = offsetof(data_t, data);
      offsets[1] = offsetof(data_t, timestamp);
      MPI_Type_create_struct(2, blocklengths, offsets, types,
                             &this->_data_type);
      MPI_Type_commit(&this->_data_type);
    }

  public:
    Spsc(MPI_Comm comm, MPI_Datatype original_type, MPI_Aint size,
         int self_rank, int dequeuer_rank)
        : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank}, _size{size} {
      this->init_data_type(original_type);

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
      MPI_Type_free(&this->_data_type);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
    }

    bool enqueue(const data_t &data) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint first;
      MPI_Aint last;
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &first, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_first_win);
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &last, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_last_win);
      MPI_Win_flush(this->_self_rank, this->_first_win);
      MPI_Win_flush(this->_self_rank, this->_last_win);

      MPI_Aint new_last = (last + 1) % this->_size;
      if (new_last == first) {
        MPI_Win_unlock_all(this->_first_win);
        MPI_Win_unlock_all(this->_last_win);
        MPI_Win_unlock_all(this->_data_win);
        return false;
      }
      MPI_Put(&data, 1, this->_data_type, this->_self_rank, last, 1,
              this->_data_type, this->_data_win);
      MPI_Win_flush(this->_self_rank, this->_data_win);
      MPI_Accumulate(&new_last, 1, MPI_AINT, this->_self_rank, 0, 1, MPI_AINT,
                     MPI_REPLACE, this->_last_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);

      return true;
    }

    void read_front(uint32_t *&output_timestamp) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint first;
      MPI_Aint last;
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &first, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_first_win);
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &last, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_last_win);
      MPI_Win_flush(this->_self_rank, this->_first_win);
      MPI_Win_flush(this->_self_rank, this->_last_win);

      if (last == first) {
        MPI_Win_unlock_all(this->_first_win);
        MPI_Win_unlock_all(this->_last_win);
        MPI_Win_unlock_all(this->_data_win);
        output_timestamp = NULL;
        return;
      }
      data_t data;
      MPI_Get_accumulate(NULL, 0, MPI_INT, &data, 1, this->_data_type,
                         this->_self_rank, first, 1, this->_data_type,
                         MPI_NO_OP, this->_data_win);
      MPI_Win_flush(this->_self_rank, this->_data_win);
      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      *output_timestamp = data.timestamp;
    }
  } _spsc;

  void _init_tree_node_type() {
    int blocklengths[] = {1, 1};
    MPI_Datatype types[] = {MPI_INT32_T, MPI_UINT32_T};
    MPI_Aint offsets[2];
    offsets[0] = offsetof(tree_node_t, rank);
    offsets[1] = offsetof(tree_node_t, tag);
    MPI_Type_create_struct(2, blocklengths, offsets, types,
                           &this->_tree_node_type);
    MPI_Type_commit(&this->_tree_node_type);
  }

  void _init_timestamp_type() {
    int blocklengths[] = {1, 1};
    MPI_Datatype types[] = {MPI_UINT32_T, MPI_UINT32_T};
    MPI_Aint offsets[2];
    offsets[0] = offsetof(timestamp_t, timestamp);
    offsets[1] = offsetof(timestamp_t, tag);
    MPI_Type_create_struct(2, blocklengths, offsets, types,
                           &this->_timestamp_type);
    MPI_Type_commit(&this->_timestamp_type);
  }

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
    MPI_Get_accumulate(NULL, 0, MPI_INT, &min_timestamp, 1,
                       this->_timestamp_type, this->_self_rank, 0, 1,
                       this->_timestamp_type, MPI_NO_OP,
                       this->_min_timestamp_win);
    MPI_Win_unlock_all(this->_min_timestamp_win);

    MPI_Win_lock_all(0, this->_tree_win);
    MPI_Get_accumulate(NULL, 0, MPI_INT, &self_node, 1, this->_tree_node_type,
                       this->_dequeuer_rank, self_index, 1,
                       this->_tree_node_type, MPI_NO_OP, this->_tree_win);
    MPI_Win_flush(this->_self_rank, this->_tree_win);
    if (min_timestamp.timestamp == MAX_TIMESTAMP) {
      const tree_node_t new_node = {DUMMY_RANK, self_node.tag + 1};
      tree_node_t result_node;
      MPI_Compare_and_swap(&new_node, &self_node, &result_node,
                           this->_tree_node_type, this->_dequeuer_rank,
                           self_index, this->_tree_win);
      res = result_node.rank == self_node.rank &&
            result_node.tag == self_node.tag;
    } else {
      const tree_node_t new_node = {this->_self_rank, self_node.tag + 1};
      tree_node_t result_node;
      MPI_Compare_and_swap(&new_node, &self_node, &result_node,
                           this->_tree_node_type, this->_dequeuer_rank,
                           self_index, this->_tree_win);
      res = result_node.rank == self_node.rank &&
            result_node.tag == self_node.tag;
    }
    MPI_Win_unlock_all(this->_tree_win);
    return res;
  }

  bool _refresh_timestamp() {
    bool res;

    uint32_t min_timestamp;
    uint32_t *min_timestamp_ptr = &min_timestamp;
    this->_spsc.read_front(min_timestamp_ptr);

    MPI_Win_lock_all(0, this->_min_timestamp_win);
    timestamp_t current_timestamp;
    MPI_Get_accumulate(NULL, 0, MPI_INT, &current_timestamp, 1,
                       this->_timestamp_type, this->_self_rank, 0, 1,
                       this->_timestamp_type, MPI_NO_OP,
                       this->_min_timestamp_win);
    MPI_Win_flush(this->_self_rank, this->_min_timestamp_win);
    if (min_timestamp_ptr == NULL) {
      const timestamp_t new_timestamp = {MAX_TIMESTAMP,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      MPI_Compare_and_swap(&new_timestamp, &current_timestamp,
                           &result_timestamp, this->_timestamp_type,
                           this->_self_rank, 0, this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            result_timestamp.timestamp == current_timestamp.timestamp;
    } else {

      const timestamp_t new_timestamp = {min_timestamp,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      MPI_Compare_and_swap(&new_timestamp, &current_timestamp,
                           &result_timestamp, this->_timestamp_type,
                           this->_self_rank, 0, this->_min_timestamp_win);
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
    MPI_Get_accumulate(NULL, 0, MPI_INT, &current_node, 1,
                       this->_tree_node_type, this->_dequeuer_rank,
                       current_index, 1, this->_tree_node_type, MPI_NO_OP,
                       this->_tree_win);
    MPI_Win_flush_all(this->_tree_win);
    for (const int child_index : this->_get_children_indexes(current_index)) {
      tree_node_t child_node;
      MPI_Get_accumulate(NULL, 0, MPI_INT, &child_node, 1,
                         this->_tree_node_type, this->_dequeuer_rank,
                         child_index, 1, this->_tree_node_type, MPI_NO_OP,
                         this->_tree_win);
      MPI_Win_flush_all(this->_tree_win);
      if (child_node.rank == DUMMY_RANK) {
        continue;
      }
      MPI_Win_lock_all(0, this->_min_timestamp_win);
      timestamp_t child_timestamp;
      MPI_Get_accumulate(NULL, 0, MPI_INT, &child_timestamp, 1,
                         this->_timestamp_type, child_node.rank, 0, 1,
                         this->_timestamp_type, MPI_NO_OP,
                         this->_min_timestamp_win);
      MPI_Win_unlock_all(this->_min_timestamp_win);
      if (child_timestamp.timestamp < min_timestamp) {
        min_timestamp = child_timestamp.timestamp;
        min_timestamp_rank = child_node.rank;
      }
    }
    MPI_Win_unlock_all(this->_tree_win);
    MPI_Win_lock_all(0, this->_tree_win);
    const tree_node_t new_node = {min_timestamp_rank, current_node.tag + 1};
    tree_node_t result_node;
    MPI_Compare_and_swap(&new_node, &current_node, &result_node,
                         this->_tree_node_type, this->_dequeuer_rank,
                         current_index, this->_tree_win);
    MPI_Win_unlock_all(this->_tree_win);
    return result_node.tag == current_node.tag &&
           result_node.rank == current_node.rank;
  }

public:
  LTEnqueuer(MPI_Comm comm, MPI_Datatype type, MPI_Aint size, int self_rank,
             int dequeuer_rank)
      : _comm{comm}, _t_type{type}, _self_rank{self_rank},
        _dequeuer_rank{dequeuer_rank},
        _enqueuer_order{self_rank > dequeuer_rank ? self_rank - 1 : self_rank},
        _spsc{comm, type, size, self_rank, dequeuer_rank} {
    this->_init_tree_node_type();
    this->_init_timestamp_type();

    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(0, sizeof(uint32_t), info, comm, &this->_counter_ptr,
                     &this->_counter_win);

    MPI_Win_allocate(sizeof(timestamp_t), sizeof(timestamp_t), info, comm,
                     &this->_min_timestamp_ptr, &this->_min_timestamp_win);

    MPI_Win_lock_all(0, this->_min_timestamp_win);
    const timestamp_t start_timestamp = {MAX_TIMESTAMP, 0};
    MPI_Accumulate(&start_timestamp, 1, this->_timestamp_type, this->_self_rank,
                   0, 1, this->_timestamp_type, MPI_REPLACE,
                   this->_min_timestamp_win);
    MPI_Win_unlock_all(this->_min_timestamp_win);

    MPI_Win_allocate(0, sizeof(tree_node_t), info, comm, &this->_tree_ptr,
                     &this->_tree_win);

    MPI_Barrier(comm);
  }
  LTEnqueuer(const LTEnqueuer &) = delete;
  LTEnqueuer &operator=(const LTEnqueuer &) = delete;
  ~LTEnqueuer() {
    MPI_Type_free(&this->_tree_node_type);
    MPI_Type_free(&this->_timestamp_type);
    MPI_Win_free(&this->_tree_win);
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
  }

  bool enqueue(const T &data) {
    MPI_Win_lock_all(0, this->_counter_win);
    const uint32_t increment = 1;
    uint32_t timestamp;
    MPI_Fetch_and_op(&increment, &timestamp, MPI_UINT32_T, this->_dequeuer_rank,
                     0, MPI_SUM, this->_counter_win);
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
  MPI_Datatype _tree_node_type;

  struct timestamp_t {
    uint32_t timestamp;
    uint32_t tag;
  };
  constexpr static uint32_t MAX_TIMESTAMP = ~((uint32_t)0);
  MPI_Datatype _timestamp_type;

  struct data_t {
    T data;
    uint32_t timestamp;
  };

  MPI_Datatype _t_type;

  int _self_rank;
  MPI_Comm _comm;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  MPI_Win _tree_win;
  tree_node_t *_tree_ptr;

  class Spsc {
    MPI_Datatype _data_type;
    MPI_Aint _self_rank;

    MPI_Aint _size;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;

    void init_data_type(MPI_Datatype original_type) {
      int blocklengths[] = {1, 1};
      MPI_Datatype types[] = {original_type, MPI_UINT32_T};
      MPI_Aint offsets[2];
      offsets[0] = offsetof(data_t, data);
      offsets[1] = offsetof(data_t, timestamp);
      MPI_Type_create_struct(2, blocklengths, offsets, types,
                             &this->_data_type);
      MPI_Type_commit(&this->_data_type);
    }

  public:
    Spsc(MPI_Comm comm, MPI_Datatype original_type, MPI_Aint size,
         int self_rank)
        : _self_rank{self_rank}, _size{size} {
      this->init_data_type(original_type);

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
      MPI_Type_free(&this->_data_type);
      MPI_Win_free(&this->_data_win);
      MPI_Win_free(&this->_first_win);
      MPI_Win_free(&this->_last_win);
    }

    void dequeue(data_t *&output, int enqueuer_rank) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint first;
      MPI_Aint last;
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &first, 1, MPI_AINT, enqueuer_rank,
                         0, 1, MPI_AINT, MPI_NO_OP, this->_first_win);
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &last, 1, MPI_AINT, enqueuer_rank,
                         0, 1, MPI_AINT, MPI_NO_OP, this->_last_win);
      MPI_Win_flush(enqueuer_rank, this->_first_win);
      MPI_Win_flush(enqueuer_rank, this->_last_win);
      if (first == last) {
        output = NULL;
        MPI_Win_unlock_all(this->_first_win);
        MPI_Win_unlock_all(this->_last_win);
        MPI_Win_unlock_all(this->_data_win);
        return;
      }

      MPI_Get(output, 1, this->_data_type, enqueuer_rank, first, 1,
              this->_data_type, this->_data_win);
      MPI_Win_flush(enqueuer_rank, this->_data_win);

      MPI_Aint new_first = (first + 1) % this->_size;
      MPI_Accumulate(&new_first, 1, MPI_AINT, enqueuer_rank, 0, 1, MPI_AINT,
                     MPI_REPLACE, this->_first_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
    }

    void read_front(uint32_t *&output_timestamp) {
      MPI_Win_lock_all(0, this->_first_win);
      MPI_Win_lock_all(0, this->_last_win);
      MPI_Win_lock_all(0, this->_data_win);

      MPI_Aint first;
      MPI_Aint last;
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &first, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_first_win);
      MPI_Get_accumulate(NULL, 0, MPI_AINT, &last, 1, MPI_AINT,
                         this->_self_rank, 0, 1, MPI_AINT, MPI_NO_OP,
                         this->_last_win);
      MPI_Win_flush(this->_self_rank, this->_first_win);
      MPI_Win_flush(this->_self_rank, this->_last_win);

      if (last == first) {
        MPI_Win_unlock_all(this->_first_win);
        MPI_Win_unlock_all(this->_last_win);
        MPI_Win_unlock_all(this->_data_win);
        output_timestamp = NULL;
        return;
      }
      data_t data;
      MPI_Get_accumulate(NULL, 0, MPI_INT, &data, 1, this->_data_type,
                         this->_self_rank, first, 1, this->_data_type,
                         MPI_NO_OP, this->_data_win);
      MPI_Win_flush(this->_self_rank, this->_data_win);
      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      *output_timestamp = data.timestamp;
    }
  } _spsc;

  void _init_tree_node_type() {
    int blocklengths[] = {1, 1};
    MPI_Datatype types[] = {MPI_INT32_T, MPI_UINT32_T};
    MPI_Aint offsets[2];
    offsets[0] = offsetof(tree_node_t, rank);
    offsets[1] = offsetof(tree_node_t, tag);
    MPI_Type_create_struct(2, blocklengths, offsets, types,
                           &this->_tree_node_type);
    MPI_Type_commit(&this->_tree_node_type);
  }

  void _init_timestamp_type() {
    int blocklengths[] = {1, 1};
    MPI_Datatype types[] = {MPI_UINT32_T, MPI_UINT32_T};
    MPI_Aint offsets[2];
    offsets[0] = offsetof(timestamp_t, timestamp);
    offsets[1] = offsetof(timestamp_t, tag);
    MPI_Type_create_struct(2, blocklengths, offsets, types,
                           &this->_timestamp_type);
    MPI_Type_commit(&this->_timestamp_type);
  }

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
    uint32_t *min_timestamp_ptr = &min_timestamp;
    this->_spsc.read_front(min_timestamp_ptr);

    MPI_Win_lock_all(0, this->_min_timestamp_win);
    timestamp_t current_timestamp;
    MPI_Get_accumulate(NULL, 0, MPI_INT, &current_timestamp, 1,
                       this->_timestamp_type, enqueuer_rank, 0, 1,
                       this->_timestamp_type, MPI_NO_OP,
                       this->_min_timestamp_win);
    MPI_Win_flush(enqueuer_rank, this->_min_timestamp_win);
    if (min_timestamp_ptr == NULL) {
      const timestamp_t new_timestamp = {MAX_TIMESTAMP,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      MPI_Compare_and_swap(&new_timestamp, &current_timestamp,
                           &result_timestamp, this->_timestamp_type,
                           enqueuer_rank, 0, this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            result_timestamp.timestamp == current_timestamp.timestamp;
    } else {

      const timestamp_t new_timestamp = {min_timestamp,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      MPI_Compare_and_swap(&new_timestamp, &current_timestamp,
                           &result_timestamp, this->_timestamp_type,
                           enqueuer_rank, 0, this->_min_timestamp_win);
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
    MPI_Get_accumulate(NULL, 0, MPI_INT, &min_timestamp, 1,
                       this->_timestamp_type, this->_self_rank, 0, 1,
                       this->_timestamp_type, MPI_NO_OP,
                       this->_min_timestamp_win);
    MPI_Win_unlock_all(this->_min_timestamp_win);

    MPI_Win_lock_all(0, this->_tree_win);

    MPI_Get_accumulate(NULL, 0, MPI_INT, &self_node, 1, this->_tree_node_type,
                       this->_self_rank, self_index, 1, this->_tree_node_type,
                       MPI_NO_OP, this->_tree_win);
    MPI_Win_flush(this->_self_rank, this->_tree_win);
    if (min_timestamp.timestamp == MAX_TIMESTAMP) {
      const tree_node_t new_node = {DUMMY_RANK, self_node.tag + 1};
      tree_node_t result_node;
      MPI_Compare_and_swap(&new_node, &self_node, &result_node,
                           this->_tree_node_type, this->_self_rank, self_index,
                           this->_tree_win);
      res = result_node.tag == self_node.tag &&
            result_node.rank == self_node.rank;
    } else {
      const tree_node_t new_node = {this->_self_rank, self_node.tag + 1};
      tree_node_t result_node;
      MPI_Compare_and_swap(&new_node, &self_node, &result_node,
                           this->_tree_node_type, this->_self_rank, self_index,
                           this->_tree_win);
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
    MPI_Get_accumulate(NULL, 0, MPI_INT, &current_node, 1,
                       this->_tree_node_type, this->_self_rank, current_index,
                       1, this->_tree_node_type, MPI_NO_OP, this->_tree_win);
    MPI_Win_flush_all(this->_tree_win);
    for (const int child_index : this->_get_children_indexes(current_index)) {
      tree_node_t child_node;
      MPI_Get_accumulate(NULL, 0, MPI_INT, &child_node, 1,
                         this->_tree_node_type, this->_self_rank, child_index,
                         1, this->_tree_node_type, MPI_NO_OP, this->_tree_win);
      MPI_Win_flush_all(this->_tree_win);
      if (child_node.rank == DUMMY_RANK) {
        continue;
      }
      MPI_Win_lock_all(0, this->_min_timestamp_win);
      timestamp_t child_timestamp;
      MPI_Get_accumulate(NULL, 0, MPI_INT, &child_timestamp, 1,
                         this->_timestamp_type, child_node.rank, 0, 1,
                         this->_timestamp_type, MPI_NO_OP,
                         this->_min_timestamp_win);
      MPI_Win_unlock_all(this->_min_timestamp_win);
      if (child_timestamp.timestamp < min_timestamp) {
        min_timestamp = child_timestamp.timestamp;
        min_timestamp_rank = child_node.rank;
      }
    }
    MPI_Win_unlock_all(this->_tree_win);
    MPI_Win_lock_all(0, this->_tree_win);
    const tree_node_t new_node = {min_timestamp_rank, current_node.tag + 1};
    tree_node_t result_node;
    MPI_Compare_and_swap(&new_node, &current_node, &result_node,
                         this->_tree_node_type, this->_self_rank, current_index,
                         this->_tree_win);
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
  LTDequeuer(MPI_Comm comm, MPI_Datatype type, MPI_Aint size, int self_rank)
      : _comm{comm}, _t_type{type}, _self_rank{self_rank},
        _spsc{comm, type, size, self_rank} {
    this->_init_tree_node_type();
    this->_init_timestamp_type();

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
    MPI_Type_free(&this->_tree_node_type);
    MPI_Type_free(&this->_timestamp_type);
    MPI_Win_free(&this->_tree_win);
    MPI_Win_free(&this->_min_timestamp_win);
    MPI_Win_free(&this->_counter_win);
  }

  void dequeue(T *&output) {
    MPI_Win_lock_all(0, this->_tree_win);
    tree_node_t root;
    MPI_Get_accumulate(NULL, 0, MPI_INT, &root, 1, this->_tree_node_type,
                       this->_self_rank, 0, 1, this->_tree_node_type, MPI_NO_OP,
                       this->_tree_win);
    MPI_Win_unlock_all(this->_tree_win);

    if (root.rank == DUMMY_RANK) {
      output = NULL;
      return;
    }
    data_t spsc_output;
    data_t *spsc_ouput_ptr;
    this->_spsc.dequeue(spsc_ouput_ptr, root.rank);
    if (!this->_refresh_timestamp(root.rank)) {
      this->_refresh_timestamp(root.rank);
    }
    this->_propagate(root.rank);
    *output = spsc_output.data;
  }
};
