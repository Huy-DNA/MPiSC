#pragma once

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T> class LTEnqueuer {
private:
  struct tree_node_t {
    int32_t rank;
    uint32_t tag;
  };

  struct data_t {
    T data;
    std::uint64_t timestamp;
  };

  constexpr static MPI_Aint NULL_INDEX = ~((MPI_Aint)0);

  MPI_Datatype _mpi_type;
  MPI_Datatype _tree_node_type;

  MPI_Comm _comm;
  int _self_rank;
  int _dequeuer_rank;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  MPI_Win _tree_win;
  tree_node_t *_tree_ptr;

  class Spsc {
    MPI_Datatype _mpi_type;
    int _self_rank;
    int _dequeuer_rank;

    MPI_Aint _size;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;

    void init_mpi_type(MPI_Datatype original_type) {
      int blocklengths[] = {1, 1};
      MPI_Datatype types[] = {original_type, MPI_UINT64_T};
      MPI_Aint offsets[2];
      offsets[0] = offsetof(data_t, data);
      offsets[1] = offsetof(data_t, timestamp);
      MPI_Type_create_struct(2, blocklengths, offsets, types, &this->_mpi_type);
      MPI_Type_commit(&this->_mpi_type);
    }

  public:
    Spsc(MPI_Comm comm, MPI_Datatype original_type, MPI_Aint size,
         int self_rank, int dequeuer_rank)
        : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank}, _size{size} {
      this->init_mpi_type(original_type);

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
      MPI_Type_free(&this->_mpi_type);
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
      MPI_Put(&data, 1, this->_mpi_type, this->_self_rank, last, 1,
              this->_mpi_type, this->_data_win);
      MPI_Win_flush(this->_self_rank, this->_data_win);
      MPI_Accumulate(&new_last, 1, MPI_AINT, this->_self_rank, 0, 1, MPI_AINT,
                     MPI_REPLACE, this->_last_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);

      return true;
    }

    void read_front(std::uint64_t *&output_timestamp) {
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
      MPI_Get_accumulate(&data, 1, this->_mpi_type, this->_self_rank, first, 1,
                         this->_mpi_type, this->_data_win);
      MPI_Win_flush(this->_self_rank, this->_data_win);
      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      output_timestamp = data.timestamp;
    }
  } _spsc;

  void init_tree_node_type() {
    int blocklengths[] = {1, 1};
    MPI_Datatype types[] = {MPI_INT32_T, MPI_UINT32_T};
    MPI_Aint offsets[2];
    offsets[0] = offsetof(tree_node_t, rank);
    offsets[1] = offsetof(tree_node_t, tag);
    MPI_Type_create_struct(2, blocklengths, offsets, types,
                           &this->_tree_node_type);
    MPI_Type_commit(&this->_tree_node_type);
  }

  int get_tree_size() {
    int number_processes;
    MPI_Comm_size(this->_comm, &number_processes);

    int number_enqueuers = number_processes - 1;
    return (2 * number_enqueuers) + 1;
  }

  int parent_index(int index) {
    if (index == 0) {
      return -1;
    }
    return index / 2;
  }

public:
  LTEnqueuer(MPI_Comm comm, MPI_Datatype type, MPI_Aint size, int self_rank,
             int dequeuer_rank)
      : _comm{comm}, _mpi_type{type}, _self_rank{self_rank},
        _dequeuer_rank{dequeuer_rank},
        _spsc{comm, type, size, self_rank, dequeuer_rank} {
    init_tree_node_type();

    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(0, sizeof(MPI_Aint), info, comm, &this->_counter_ptr,
                     &this->_counter_win);

    MPI_Win_allocate(0, sizeof(tree_node_t), info, comm, &this->_tree_ptr,
                     &this->_tree_win);

    MPI_Barrier(comm);
  }
  LTEnqueuer(const LTEnqueuer &) = delete;
  LTEnqueuer &operator=(const LTEnqueuer &) = delete;
  ~LTEnqueuer() {
    MPI_Type_free(&this->_tree_node_type);
    MPI_Win_free(&this->_tree_win);
    MPI_Win_free(&this->_counter_win);
  }
};

template <typename T> class LTDequeuer {
private:
  struct tree_node_t {
    int32_t rank;
    uint32_t tag;
  };

  struct data_t {
    T data;
    std::uint64_t timestamp;
  };

  constexpr static MPI_Aint NULL_INDEX = ~((MPI_Aint)0);

  MPI_Datatype _mpi_type;
  MPI_Datatype _tree_node_type;

  int _self_rank;
  MPI_Comm _comm;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;

  MPI_Win _tree_win;
  tree_node_t *_tree_ptr;

  class Spsc {
    MPI_Datatype _mpi_type;
    MPI_Aint _self_rank;

    MPI_Aint _size;

    MPI_Win _data_win;
    data_t *_data_ptr;

    MPI_Win _first_win;
    MPI_Aint *_first_ptr;

    MPI_Win _last_win;
    MPI_Aint *_last_ptr;

    void init_mpi_type(MPI_Datatype original_type) {
      int blocklengths[] = {1, 1};
      MPI_Datatype types[] = {original_type, MPI_UINT64_T};
      MPI_Aint offsets[2];
      offsets[0] = offsetof(data_t, data);
      offsets[1] = offsetof(data_t, timestamp);
      MPI_Type_create_struct(2, blocklengths, offsets, types, &this->_mpi_type);
      MPI_Type_commit(&this->_mpi_type);
    }

  public:
    Spsc(MPI_Comm comm, MPI_Datatype original_type, MPI_Aint size,
         int self_rank)
        : _self_rank{self_rank}, _size{size} {
      this->init_mpi_type(original_type);

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
      MPI_Type_free(&this->_mpi_type);
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

      MPI_Get(output, 1, this->_mpi_type, enqueuer_rank, first, 1,
              this->_mpi_type, this->_data_win);
      MPI_Win_flush(enqueuer_rank, this->_data_win);

      MPI_Aint new_first = (first + 1) % this->_size;
      MPI_Accumulate(&new_first, 1, MPI_AINT, enqueuer_rank, 0, 1, MPI_AINT,
                     MPI_REPLACE, this->_first_win);

      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
    }

    void read_front(std::uint64_t *&output_timestamp) {
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
      MPI_Get_accumulate(&data, 1, this->_mpi_type, this->_self_rank, first, 1,
                         this->_mpi_type, this->_data_win);
      MPI_Win_flush(this->_self_rank, this->_data_win);
      MPI_Win_unlock_all(this->_first_win);
      MPI_Win_unlock_all(this->_last_win);
      MPI_Win_unlock_all(this->_data_win);
      output_timestamp = data.timestamp;
    }
  } _spsc;

  void init_tree_node_type() {
    int blocklengths[] = {1, 1};
    MPI_Datatype types[] = {MPI_INT32_T, MPI_UINT32_T};
    MPI_Aint offsets[2];
    offsets[0] = offsetof(tree_node_t, rank);
    offsets[1] = offsetof(tree_node_t, tag);
    MPI_Type_create_struct(2, blocklengths, offsets, types,
                           &this->_tree_node_type);
    MPI_Type_commit(&this->_tree_node_type);
  }

  int get_tree_size() {
    int number_processes;
    MPI_Comm_size(this->_comm, &number_processes);

    int number_enqueuers = number_processes - 1;
    return (2 * number_enqueuers) + 1;
  }

  int parent_index(int index) {
    if (index == 0) {
      return -1;
    }
    return index / 2;
  }

public:
  LTDequeuer(MPI_Comm comm, MPI_Datatype type, MPI_Aint size, int self_rank)
      : _comm{comm}, _mpi_type{type}, _self_rank{self_rank},
        _spsc{comm, type, size, self_rank} {
    this->init_tree_node_type();
    MPI_Info info;
    MPI_Info_create(&info);
    MPI_Info_set(info, "same_disp_unit", "true");

    MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), info, comm,
                     &this->_counter_ptr, &this->_counter_win);
    MPI_Win_lock_all(0, this->_counter_win);
    *this->_counter_ptr = 0;
    MPI_Win_unlock_all(this->_counter_win);

    MPI_Win_allocate(this->get_tree_size() * sizeof(tree_node_t),
                     sizeof(tree_node_t), info, comm, &this->_tree_ptr,
                     &this->_tree_win);

    MPI_Barrier(comm);
  }
  LTDequeuer(const LTDequeuer &) = delete;
  LTDequeuer &operator=(const LTDequeuer &) = delete;
  ~LTDequeuer() {
    MPI_Type_free(&this->_tree_node_type);
    MPI_Win_free(&this->_tree_win);
    MPI_Win_free(&this->_counter_win);
  }
};
