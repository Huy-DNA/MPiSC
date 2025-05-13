#pragma once

#include "bclx/bclx.hpp"
#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T, int SEGMENT_SIZE = 1024> class JiffyEnqueuer {
private:
  enum status_t {
    SET,
    HANDLED,
    EMPTY,
  };

  struct segment_t {
    BCL::GlobalPtr<T[SEGMENT_SIZE]> curr_data_buffer;
    BCL::GlobalPtr<status_t[SEGMENT_SIZE]> curr_status_buffer;
    BCL::GlobalPtr<segment_t> next;
    BCL::GlobalPtr<segment_t> prev;
    int head;
    int pos_in_queue;
  };

  BCL::GlobalPtr<int> _tail;
  BCL::GlobalPtr<segment_t> _head_of_queue;
  BCL::GlobalPtr<segment_t> _tail_of_queue;

public:
  JiffyEnqueuer(int dequeuer_rank) {
    this->_tail = BCL::broadcast(_tail, dequeuer_rank);
    this->_head_of_queue = BCL::broadcast(_head_of_queue, dequeuer_rank);
    this->_tail_of_queue = BCL::broadcast(_tail_of_queue, dequeuer_rank);
  }

  JiffyEnqueuer(const JiffyEnqueuer &) = delete;
  JiffyEnqueuer &operator=(const JiffyEnqueuer &) = delete;

  ~JiffyEnqueuer() {}

  bool enqueue(const T &data) {}
};

template <typename T, int SEGMENT_SIZE = 1024> class JiffyDequeuer {
private:
  enum status_t {
    SET,
    HANDLED,
    EMPTY,
  };

  struct segment_t {
    BCL::GlobalPtr<T[SEGMENT_SIZE]> curr_data_buffer;
    BCL::GlobalPtr<status_t[SEGMENT_SIZE]> curr_status_buffer;
    BCL::GlobalPtr<segment_t> next;
    BCL::GlobalPtr<segment_t> prev;
    int head;
    int pos_in_queue;
  };

  BCL::GlobalPtr<int> _tail;
  BCL::GlobalPtr<segment_t> _head_of_queue;
  BCL::GlobalPtr<segment_t> _tail_of_queue;

public:
  JiffyDequeuer(int self_rank) {
    this->_tail = BCL::alloc<int>(1);
    *this->_tail = 0;
    this->_head_of_queue = nullptr;
    this->_tail_of_queue = nullptr;

    BCL::broadcast(_tail, self_rank);
    BCL::broadcast(_head_of_queue, self_rank);
    BCL::broadcast(_tail_of_queue, self_rank);
  }

  JiffyDequeuer(const JiffyDequeuer &) = delete;
  JiffyDequeuer &operator=(const JiffyDequeuer &) = delete;
  ~JiffyDequeuer() {
    BCL::dealloc(this->_tail);
    BCL::dealloc(this->_head_of_queue);
    BCL::dealloc(this->_tail_of_queue);
  }

  bool dequeue(T *output) {}
};
