#pragma once

#include "bclx/backends/mpi/comm.hpp"
#include "bclx/core/comm.hpp"
#include "bclx/core/definition.hpp"
#include <bclx/bclx.hpp>

#include <cstdlib>
#include <mpi.h>

template <typename T, int SEGMENT_SIZE = 32> class JiffyQueue {
private:
  enum status_t {
    SET,
    HANDLED,
    EMPTY,
  };

  struct segment_t {
    bclx::gptr<T> curr_data_buffer;
    bclx::gptr<status_t> curr_status_buffer;
    bclx::gptr<bclx::gptr<segment_t>> next;
    bclx::gptr<bclx::gptr<segment_t>> prev;
    bclx::gptr<int> head;
    int pos_in_queue;
  };

  bclx::gptr<int> _tail = nullptr;
  bclx::gptr<bclx::gptr<segment_t>> _tail_of_queue = nullptr;
  bclx::gptr<segment_t> _head_of_queue = nullptr;

public:
  JiffyQueue(int dequeuer_rank) {
    int self_rank = BCL::my_rank;
    if (self_rank == dequeuer_rank) {
      this->_tail = BCL::alloc<int>(1);
      *this->_tail = 0;

      this->_tail_of_queue = BCL::alloc<bclx::gptr<segment_t>>(1);
      *this->_tail_of_queue = BCL::alloc<segment_t>(1);
      this->_tail_of_queue.local()->local()->curr_data_buffer =
          BCL::alloc<T>(SEGMENT_SIZE);
      this->_tail_of_queue.local()->local()->curr_status_buffer =
          BCL::alloc<status_t>(SEGMENT_SIZE);
      for (int i = 0; i < SEGMENT_SIZE; ++i) {
        this->_tail_of_queue.local()->local()->curr_status_buffer.local()[i] =
            EMPTY;
      }
      this->_tail_of_queue.local()->local()->next =
          BCL::alloc<bclx::gptr<segment_t>>(1);
      *this->_tail_of_queue.local()->local()->next.local() = nullptr;
      this->_tail_of_queue.local()->local()->prev =
          BCL::alloc<bclx::gptr<segment_t>>(1);
      *this->_tail_of_queue.local()->local()->prev.local() = nullptr;
      this->_tail_of_queue.local()->local()->head = BCL::alloc<int>(1);
      *this->_tail_of_queue.local()->local()->head.local() = 0;
      this->_tail_of_queue.local()->local()->pos_in_queue = 0;

      this->_head_of_queue = *this->_tail_of_queue.local();

      BCL::broadcast(_tail, self_rank);
      BCL::broadcast(_tail_of_queue, self_rank);

    } else {
      this->_tail = BCL::broadcast(_tail, dequeuer_rank);
      this->_tail_of_queue = BCL::broadcast(_tail_of_queue, dequeuer_rank);
    }
  }

  JiffyQueue(const JiffyQueue &) = delete;
  JiffyQueue &operator=(const JiffyQueue &) = delete;
  JiffyQueue(JiffyQueue &&other) noexcept
      : _tail{other._tail}, _tail_of_queue{other._tail_of_queue},
        _head_of_queue{other._head_of_queue} {

    other._tail = nullptr;
    other._tail_of_queue = nullptr;
    other._head_of_queue = nullptr;
  }

  ~JiffyQueue() {}

  bool enqueue(const T &data) {
  }

  bool dequeue(T *output) {
  }
};
