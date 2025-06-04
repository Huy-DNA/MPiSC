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

  bclx::gptr<segment_t> allocate_segment(int pos_in_queue) {
    bclx::gptr<segment_t> segment = BCL::alloc<segment_t>(1);

    segment.local()->curr_data_buffer = BCL::alloc<T>(SEGMENT_SIZE);

    segment.local()->curr_status_buffer = BCL::alloc<status_t>(SEGMENT_SIZE);
    for (int i = 0; i < SEGMENT_SIZE; ++i) {
      segment.local()->curr_status_buffer.local()[i] = EMPTY;
    }

    segment.local()->next = BCL::alloc<bclx::gptr<segment_t>>(1);
    *segment.local()->next.local() = nullptr;

    segment.local()->prev = BCL::alloc<bclx::gptr<segment_t>>(1);
    *segment.local()->prev.local() = nullptr;

    segment.local()->head = BCL::alloc<int>(1);
    *segment.local()->head.local() = 0;

    segment.local()->pos_in_queue = pos_in_queue;

    return segment;
  }

  void _fully_reclaim_segment(bclx::gptr<segment_t> segment) {
    BCL::dealloc(segment.local()->curr_data_buffer);
    BCL::dealloc(segment.local()->curr_status_buffer);
    BCL::dealloc(segment.local()->next);
    BCL::dealloc(segment.local()->prev);
    BCL::dealloc(segment.local()->head);
    BCL::dealloc(segment);
  }

public:
  JiffyQueue(int dequeuer_rank) {
    int self_rank = BCL::my_rank;
    if (self_rank == dequeuer_rank) {
      this->_tail = BCL::alloc<int>(1);
      *this->_tail = 0;

      this->_tail_of_queue = BCL::alloc<bclx::gptr<segment_t>>(1);
      *this->_tail_of_queue = allocate_segment(0);

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

  ~JiffyQueue() {
    // free later...
  }

  bool enqueue(const T &data) {
    int location;
    int inc = 1;
    bclx::fetch_and_op_sync(this->_tail, &inc, BCL::plus<int>{}, &location);

    while (true) {
      bclx::gptr<segment_t> last_segment_ptr =
          bclx::aread_sync(this->_tail_of_queue);
      segment_t last_segment = bclx::aread_sync(last_segment_ptr);
      if ((last_segment.pos_in_queue + 1) * SEGMENT_SIZE > location) {
        break;
      }
      bclx::gptr<segment_t> new_last =
          allocate_segment(last_segment.pos_in_queue + 1);
      *new_last.local()->prev.local() = last_segment_ptr;
      bclx::gptr<segment_t> old_tail_of_queue;
      bclx::compare_and_swap_sync(this->_tail_of_queue, &last_segment_ptr,
                                  &new_last, &old_tail_of_queue);
      if (old_tail_of_queue != last_segment_ptr) {
        this->_fully_reclaim_segment(new_last);
      } else {
        bclx::aput_sync(new_last, last_segment.next);
      }
    }

    bclx::gptr<segment_t> temp_tail_ptr = bclx::aget_sync(this->_tail_of_queue);
    segment_t temp_tail = bclx::aget_sync(temp_tail_ptr);
    while (bclx::aget_sync(temp_tail_ptr.head) > location) {
      temp_tail_ptr = bclx::aget_sync(temp_tail.prev);
      temp_tail = bclx::aget_sync(temp_tail_ptr);
    }

    bclx::aput_sync(data, temp_tail.curr_data_buffer + location);
    bclx::aput_sync(SET, temp_tail.curr_status_buffer + location);
    return true;
  }

  bool dequeue(T *output) {
    bclx::gptr<segment_t> cur_segment_ptr = this->_head_of_queue;
    segment_t cur_segment = bclx::aget_sync(cur_segment_ptr);
    int cur_index = bclx::aget_sync(cur_segment.head);

    while (bclx::aget_sync(cur_segment.curr_status_buffer + cur_index) ==
           HANDLED) {
      int tmp;
      int inc = 1;
      bclx::fetch_and_op_sync(cur_segment.head, &inc, BCL::plus<int>{}, &tmp);
      ++cur_index;
      if (cur_index >= SEGMENT_SIZE) {
        // free if all read here...
        // TBD
        cur_segment_ptr = bclx::aget_sync(cur_segment.next);
        if (cur_segment_ptr == nullptr) {
          return false;
        }
        cur_segment = bclx::aget_sync(cur_segment_ptr);
        cur_index = bclx::aget_sync(cur_segment.head);
      }
    }
    bclx::gptr<segment_t> tail_segment_ptr = bclx::aget_sync(_tail_of_queue);
    segment_t tail_segment = bclx::aget_sync(tail_segment_ptr);
    int tail_index = bclx::aget_sync(this->_tail);
    if (cur_segment_ptr == tail_segment_ptr &&
        cur_index + cur_segment.pos_in_queue * SEGMENT_SIZE > tail_index) {
      return false;
    }

    int temp_index = cur_index;
    bclx::gptr<segment_t> temp_segment_ptr = cur_segment_ptr;
    bclx::gptr<segment_t> temp_segment = cur_segment;
    status_t temp_status =
        bclx::aget_sync(temp_segment.curr_status_buffer + temp_index);
    while (temp_status != SET) {
      temp_index += 1;
      if (temp_index >= SEGMENT_SIZE) {
        // free if all read here...
        // TBD
        temp_index = 0;
        temp_segment_ptr = bclx::aget_sync(temp_segment.next);
        if (temp_segment_ptr == nullptr) {
          return false;
        }
        temp_segment = bclx::aget_sync(temp_segment_ptr);
      }
      temp_status =
          bclx::aget_sync(temp_segment.curr_status_buffer + temp_index);
    }

    while (true) {
      int e_index = cur_index;
      bclx::gptr<segment_t> e_segment_ptr = cur_segment_ptr;
      bclx::gptr<segment_t> e_segment = cur_segment;
      status_t e_status =
          bclx::aget_sync(e_segment.curr_status_buffer + e_index);
      while (e_status != SET) {
        e_index += 1;
        if (e_index >= SEGMENT_SIZE) {
          e_index = 0;
          e_segment_ptr = bclx::aget_sync(e_segment.next);
          e_segment = bclx::aget_sync(e_segment_ptr);
        }
        e_status = bclx::aget_sync(e_segment.curr_status_buffer + e_index);
      }
      if (e_segment_ptr == temp_segment_ptr && e_index == temp_index) {
        break;
      }
      temp_segment_ptr = e_segment_ptr;
      temp_index = e_index;
      temp_segment = e_segment;
    }
    bclx::aput_sync(HANDLED, temp_segment.curr_status_buffer + temp_index);
    *output = bclx::aget_sync(temp_segment.curr_data_buffer + temp_index);
    return true;
  }
};
