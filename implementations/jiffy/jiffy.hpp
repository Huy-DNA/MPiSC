#pragma once

#include <bcl/bcl.hpp>

#include "bcl/backends/mpi/atomics.hpp"
#include "bcl/backends/mpi/comm.hpp"
#include "bcl/core/GlobalPtr.hpp"
#include "bcl/core/GlobalRef.hpp"
#include "bcl/core/alloc.hpp"
#include "bcl/core/comm.hpp"
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <queue>

template <typename T, int SEGMENT_SIZE = 1024> class JiffyEnqueuer {
private:
  enum status_t {
    SET,
    HANDLED,
    EMPTY,
  };

  struct segment_t {
    BCL::GlobalPtr<T> curr_data_buffer;
    BCL::GlobalPtr<status_t> curr_status_buffer;
    BCL::GlobalPtr<BCL::GlobalPtr<segment_t>> next;
    BCL::GlobalPtr<BCL::GlobalPtr<segment_t>> prev;
    BCL::GlobalPtr<int> head;
    int pos_in_queue;
  };

  BCL::GlobalPtr<int> _tail;
  BCL::GlobalPtr<BCL::GlobalPtr<segment_t>> _tail_of_queue;

public:
  JiffyEnqueuer(int dequeuer_rank) {
    this->_tail = BCL::broadcast(_tail, dequeuer_rank);
    this->_tail_of_queue = BCL::broadcast(_tail_of_queue, dequeuer_rank);
  }

  JiffyEnqueuer(const JiffyEnqueuer &) = delete;
  JiffyEnqueuer &operator=(const JiffyEnqueuer &) = delete;

  ~JiffyEnqueuer() {}

  bool enqueue(const T &data) {
    int location = BCL::fetch_and_op(this->_tail, 1, BCL::plus<int>{});
    bool is_last_buffer = true;
    BCL::GlobalPtr<segment_t> temp_tail = BCL::rget(this->_tail_of_queue);
    int num_elements = SEGMENT_SIZE * BCL::rget(temp_tail).pos_in_queue;
    while (location >= num_elements) {
      if (BCL::rget(temp_tail).next == nullptr) {
        BCL::GlobalPtr<segment_t> new_arr = BCL::alloc<segment_t>(1);
        new_arr.local()->curr_data_buffer = BCL::alloc<T>(SEGMENT_SIZE);
        new_arr.local()->curr_status_buffer =
            BCL::alloc<status_t>(SEGMENT_SIZE);
        for (int i = 0; i < SEGMENT_SIZE; ++i) {
          new_arr.local()->curr_status_buffer.local()[i] = EMPTY;
        }
        new_arr.local()->next = BCL::alloc<BCL::GlobalPtr<segment_t>>(1);
        *new_arr.local()->next.local() = nullptr;
        new_arr.local()->prev = BCL::alloc<BCL::GlobalPtr<segment_t>>(1);
        *new_arr.local()->prev.local() = temp_tail;
        new_arr.local()->head = BCL::alloc<int>(1);
        *new_arr.local()->head.local() = 0;
        new_arr.local()->pos_in_queue = BCL::rget(temp_tail).pos_in_queue + 1;
        BCL::GlobalPtr<segment_t> old_next =
            BCL::rget(BCL::rget(temp_tail).next);
        if (old_next == nullptr &&
            BCL::compare_and_swap(BCL::rget(temp_tail).next, old_next,
                                  new_arr) == old_next) {
          BCL::compare_and_swap(this->_tail_of_queue, temp_tail, new_arr);
        } else {
          BCL::dealloc(new_arr.local()->curr_data_buffer);
          BCL::dealloc(new_arr);
        }
      }
      temp_tail = *this->_tail_of_queue;
      num_elements = SEGMENT_SIZE * BCL::rget(temp_tail).pos_in_queue;
    }
    int prev_size = SEGMENT_SIZE * BCL::rget(temp_tail).pos_in_queue;
    while (location < prev_size) {
      temp_tail = BCL::rget(BCL::rget(temp_tail).prev);
      prev_size = SEGMENT_SIZE * (BCL::rget(temp_tail).pos_in_queue - 1);
      is_last_buffer = false;
    }

    status_t status;
    BCL::rget(BCL::rget(temp_tail).curr_status_buffer, &status,
              location - prev_size);
    if (status == EMPTY) {
      BCL::rput(&data, BCL::rget(temp_tail).curr_data_buffer,
                location - prev_size);
      status_t set = SET;
      BCL::rput(&set, BCL::rget(temp_tail).curr_status_buffer,
                location - prev_size);
      if (location - prev_size == 1 && is_last_buffer) {
        BCL::GlobalPtr<segment_t> new_arr = BCL::alloc<segment_t>(1);
        new_arr.local()->curr_data_buffer = BCL::alloc<T>(SEGMENT_SIZE);
        new_arr.local()->curr_status_buffer =
            BCL::alloc<status_t>(SEGMENT_SIZE);
        for (int i = 0; i < SEGMENT_SIZE; ++i) {
          new_arr.local()->curr_status_buffer.local()[i] = EMPTY;
        }
        new_arr.local()->next = BCL::alloc<BCL::GlobalPtr<segment_t>>(1);
        *new_arr.local()->next.local() = nullptr;
        new_arr.local()->prev = BCL::alloc<BCL::GlobalPtr<segment_t>>(1);
        *new_arr.local()->prev.local() = temp_tail;
        new_arr.local()->head = BCL::alloc<int>(1);
        *new_arr.local()->head.local() = 0;
        new_arr.local()->pos_in_queue = BCL::rget(temp_tail).pos_in_queue + 1;
        BCL::GlobalPtr<segment_t> old_next =
            BCL::rget(BCL::rget(temp_tail).next);
        if (old_next == nullptr &&
            BCL::compare_and_swap(BCL::rget(temp_tail).next, old_next,
                                  new_arr) == old_next) {
          BCL::compare_and_swap(this->_tail_of_queue, temp_tail, new_arr);
        } else {
          BCL::dealloc(new_arr.local()->curr_data_buffer);
          BCL::dealloc(new_arr);
        }
      }
    }
    return true;
  }
};

template <typename T, int SEGMENT_SIZE = 1024> class JiffyDequeuer {
private:
  enum status_t {
    SET,
    HANDLED,
    EMPTY,
  };

  struct segment_t {
    BCL::GlobalPtr<T> curr_data_buffer;
    BCL::GlobalPtr<status_t> curr_status_buffer;
    BCL::GlobalPtr<BCL::GlobalPtr<segment_t>> next;
    BCL::GlobalPtr<BCL::GlobalPtr<segment_t>> prev;
    BCL::GlobalPtr<int> head;
    int pos_in_queue;
  };

  BCL::GlobalPtr<int> _tail;
  BCL::GlobalPtr<segment_t> _head_of_queue;
  BCL::GlobalPtr<BCL::GlobalPtr<segment_t>> _tail_of_queue;
  std::queue<BCL::GlobalPtr<segment_t>> _garbage_list;

private:
  bool _fold(BCL::GlobalPtr<segment_t> temp_head_of_queue, int &temp_head,
             bool &flag_move_to_new_buffer, bool &flag_buffer_all_handle_id) {
    if (temp_head_of_queue == BCL::rget(this->_tail_of_queue)) {
      return false;
    }
    BCL::GlobalPtr<segment_t> next =
        BCL::rget(BCL::rget(temp_head_of_queue).next);
    BCL::GlobalPtr<segment_t> prev =
        BCL::rget(BCL::rget(temp_head_of_queue).prev);
    if (next == nullptr) {
      return false;
    }
    BCL::rput(prev, BCL::rget(next).prev);
    BCL::rput(next, BCL::rget(prev).next);
    BCL::dealloc(BCL::rget(temp_head_of_queue).curr_data_buffer);
    BCL::dealloc(BCL::rget(temp_head_of_queue).curr_status_buffer);
    this->_garbage_list.push(temp_head_of_queue);
    temp_head_of_queue = next;
    temp_head = BCL::rget(BCL::rget(temp_head_of_queue).head);
    flag_buffer_all_handle_id = true;
    flag_move_to_new_buffer = true;
    return true;
  }

  bool _move_to_next_buffer() {
    if (BCL::rget((BCL::rget(this->_head_of_queue)).head) >= SEGMENT_SIZE) {
      if (this->_head_of_queue == BCL::rget(this->_tail_of_queue)) {
        return false;
      }
      BCL::GlobalPtr<segment_t> next =
          BCL::rget(BCL::rget(_head_of_queue).next);
      if (next == nullptr) {
        return false;
      }
      if (this->_garbage_list.size()) {
        BCL::GlobalPtr<segment_t> g = this->_garbage_list.front();
        while (BCL::rget(g).pos_in_queue < BCL::rget(next).pos_in_queue) {
          this->_garbage_list.pop();
          BCL::dealloc(g);
          g = this->_garbage_list.front();
        }
      }
      BCL::dealloc(this->_head_of_queue);
      this->_head_of_queue = next;
      return true;
    }
    return true;
  }

  bool _scan(BCL::GlobalPtr<segment_t> temp_head_of_queue, int &temp_head,
             status_t &status, T &data) {
    bool flag_move_to_new_buffer = false;
    bool flag_buffer_all_handled = true;
    while (status == SET) {
      temp_head++;
      if (status != HANDLED) {
        flag_buffer_all_handled = false;
      }
      if (temp_head >= SEGMENT_SIZE) {
        if (flag_buffer_all_handled && flag_move_to_new_buffer) {
          bool res =
              this->_fold(temp_head_of_queue, temp_head,
                          flag_move_to_new_buffer, flag_buffer_all_handled);
          if (!res) {
            return false;
          }
        } else {
          BCL::GlobalPtr<segment_t> next =
              BCL::rget(BCL::rget(temp_head_of_queue).next);
          if (next == nullptr) {
            return false;
          }
          temp_head_of_queue = next;
          temp_head = BCL::rget(BCL::rget(temp_head_of_queue).head);
          flag_buffer_all_handled = true;
          flag_move_to_new_buffer = true;
        }
      }
    }
    return true;
  }

  void _rescan(BCL::GlobalPtr<segment_t> head_of_queue,
               BCL::GlobalPtr<segment_t> temp_head_of_queue, int &temp_head,
               status_t &status, T &data) {
    BCL::GlobalPtr<segment_t> scan_head_of_queue = head_of_queue;
    for (int scan_head = BCL::rget(BCL::rget(scan_head_of_queue).head);
         (scan_head_of_queue != temp_head_of_queue ||
          scan_head <= (temp_head - 1));
         scan_head++) {
      if (scan_head >= SEGMENT_SIZE) {
        scan_head_of_queue = BCL::rget(BCL::rget(scan_head_of_queue).next);
        scan_head = BCL::rget(BCL::rget(scan_head_of_queue).head);
      }
      status_t scan_status;
      T scan_data;
      BCL::rget(BCL::rget(head_of_queue).curr_status_buffer, &scan_status,
                scan_head);
      BCL::rget(BCL::rget(head_of_queue).curr_data_buffer, &scan_data,
                scan_head);
      if (scan_status == SET) {
        temp_head = scan_head;
        temp_head_of_queue = scan_head_of_queue;
        status = scan_status;
        data = scan_data;
        scan_head_of_queue = head_of_queue;
        scan_head = BCL::rget(BCL::rget(scan_head_of_queue).head);
      }
    }
  }

public:
  JiffyDequeuer(int self_rank) {
    this->_tail = BCL::alloc<int>(1);
    *this->_tail = 0;

    this->_head_of_queue = BCL::alloc<segment_t>(1);

    this->_tail_of_queue = BCL::alloc<BCL::GlobalPtr<segment_t>>(1);
    *this->_tail_of_queue = BCL::alloc<segment_t>(1);

    BCL::broadcast(_tail, self_rank);
    BCL::broadcast(_head_of_queue, self_rank);
    BCL::broadcast(_tail_of_queue, self_rank);
  }

  JiffyDequeuer(const JiffyDequeuer &) = delete;
  JiffyDequeuer &operator=(const JiffyDequeuer &) = delete;
  ~JiffyDequeuer() {
    // Just leak memory...
  }

  bool dequeue(T *output) {
    status_t status;
    T data;
    segment_t head_of_queue = *this->_head_of_queue;
    BCL::rget(head_of_queue.curr_status_buffer, &status,
              BCL::rget(head_of_queue.head));
    BCL::rget(head_of_queue.curr_data_buffer, &data,
              BCL::rget(head_of_queue.head));
    while (status == HANDLED) {
      BCL::fetch_and_op(head_of_queue.head, 1, BCL::plus<int>{});
      bool res = this->_move_to_next_buffer();
      if (!res) {
        return false;
      }
      BCL::rget(head_of_queue.curr_status_buffer, &status,
                BCL::rget(head_of_queue.head));
      BCL::rget(head_of_queue.curr_data_buffer, &data,
                BCL::rget(head_of_queue.head));
    }

    if ((this->_head_of_queue == BCL::rget(this->_tail_of_queue)) &&
        BCL::rget(BCL::rget(this->_head_of_queue).head) ==
            *this->_tail % SEGMENT_SIZE) {
      return false;
    }

    if (status == SET) {
      BCL::fetch_and_op(head_of_queue.head, 1, BCL::plus<int>{});
      this->_move_to_next_buffer();
      *output = data;
      return true;
    }

    if (status == EMPTY) {
      BCL::GlobalPtr<segment_t> temp_head_of_queue = this->_head_of_queue;
      int temp_head = BCL::rget(BCL::rget(this->_head_of_queue).head);
      BCL::rget(BCL::rget(temp_head_of_queue).curr_status_buffer, &status,
                temp_head);
      BCL::rget(BCL::rget(temp_head_of_queue).curr_data_buffer, &data,
                temp_head);
      bool res = this->_scan(temp_head_of_queue, temp_head, status, data);
      if (!res) {
        return false;
      }
      this->_rescan(this->_head_of_queue, temp_head_of_queue, temp_head, status,
                    data);
      *output = data;
      status_t handled = HANDLED;
      BCL::rput(&handled, BCL::rget(temp_head_of_queue).curr_status_buffer,
                temp_head);
      if (temp_head_of_queue == this->_head_of_queue &&
          temp_head == BCL::rget(BCL::rget(this->_head_of_queue).head)) {
        BCL::fetch_and_op(head_of_queue.head, 1, BCL::plus<int>{});
        this->_move_to_next_buffer();
      }
      return true;
    }

    return false;
  }
};
