#pragma once

#include "bclx/backends/mpi/comm.hpp"
#include "bclx/core/comm.hpp"
#include "bclx/core/definition.hpp"
#include <bclx/bclx.hpp>

#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T, int SEGMENT_SIZE = 32> class NaiveJiffyEnqueuer {
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

  bclx::gptr<int> _tail;
  bclx::gptr<bclx::gptr<segment_t>> _tail_of_queue;

public:
  NaiveJiffyEnqueuer(int dequeuer_rank) {
    this->_tail = BCL::broadcast(_tail, dequeuer_rank);
    this->_tail_of_queue = BCL::broadcast(_tail_of_queue, dequeuer_rank);
  }

  NaiveJiffyEnqueuer(const NaiveJiffyEnqueuer &) = delete;
  NaiveJiffyEnqueuer &operator=(const NaiveJiffyEnqueuer &) = delete;

  ~NaiveJiffyEnqueuer() {}

  bool enqueue(const T &data) {
    int location;
    int inc = 1;
    bclx::fetch_and_op_sync(this->_tail, &inc, BCL::plus<int>{}, &location);
    bool is_last_buffer = true;
    bclx::gptr<segment_t> temp_tail = bclx::aget_sync(this->_tail_of_queue);

    int num_elements =
        SEGMENT_SIZE * (bclx::aget_sync(temp_tail).pos_in_queue + 1);
    while (location >= num_elements) {
      if (bclx::aget_sync(temp_tail).next == nullptr) {
        bclx::gptr<segment_t> new_arr = BCL::alloc<segment_t>(1);
        new_arr.local()->curr_data_buffer = BCL::alloc<T>(SEGMENT_SIZE);
        new_arr.local()->curr_status_buffer =
            BCL::alloc<status_t>(SEGMENT_SIZE);
        for (int i = 0; i < SEGMENT_SIZE; ++i) {
          new_arr.local()->curr_status_buffer.local()[i] = EMPTY;
        }
        new_arr.local()->next = BCL::alloc<bclx::gptr<segment_t>>(1);
        *new_arr.local()->next.local() = nullptr;
        new_arr.local()->prev = BCL::alloc<bclx::gptr<segment_t>>(1);
        *new_arr.local()->prev.local() = temp_tail;
        new_arr.local()->head = BCL::alloc<int>(1);
        *new_arr.local()->head.local() = 0;
        new_arr.local()->pos_in_queue =
            bclx::aget_sync(temp_tail).pos_in_queue + 1;
        bclx::gptr<segment_t> old_next =
            bclx::aget_sync(bclx::aget_sync(temp_tail).next);
        bclx::gptr<segment_t> result;
        bclx::compare_and_swap_sync(bclx::aget_sync(temp_tail).next, &old_next,
                                    &new_arr, &result);
        if (old_next == nullptr && result == old_next) {
          bclx::gptr<segment_t> tmp;
          bclx::compare_and_swap_sync(this->_tail_of_queue, &temp_tail,
                                      &new_arr, &tmp);
        } else {
          BCL::dealloc(new_arr.local()->curr_data_buffer);
          BCL::dealloc(new_arr);
        }
      }
      temp_tail = *this->_tail_of_queue;
      num_elements = SEGMENT_SIZE * bclx::aget_sync(temp_tail).pos_in_queue;
    }
    int prev_size = SEGMENT_SIZE * bclx::aget_sync(temp_tail).pos_in_queue;
    while (location < prev_size) {
      temp_tail = bclx::aget_sync(bclx::aget_sync(temp_tail).prev);
      prev_size = SEGMENT_SIZE * bclx::aget_sync(temp_tail).pos_in_queue;
      is_last_buffer = false;
    }

    bclx::aput_sync(data, bclx::aget_sync(temp_tail).curr_data_buffer +
                              location - prev_size);
    bclx::aput_sync(SET, bclx::aget_sync(temp_tail).curr_status_buffer +
                             location - prev_size);

    if (location - prev_size == 1 && is_last_buffer) {
      bclx::gptr<segment_t> new_arr = BCL::alloc<segment_t>(1);
      new_arr.local()->curr_data_buffer = BCL::alloc<T>(SEGMENT_SIZE);
      new_arr.local()->curr_status_buffer = BCL::alloc<status_t>(SEGMENT_SIZE);
      for (int i = 0; i < SEGMENT_SIZE; ++i) {
        new_arr.local()->curr_status_buffer.local()[i] = EMPTY;
      }
      new_arr.local()->next = BCL::alloc<bclx::gptr<segment_t>>(1);
      *new_arr.local()->next.local() = nullptr;
      new_arr.local()->prev = BCL::alloc<bclx::gptr<segment_t>>(1);
      *new_arr.local()->prev.local() = temp_tail;
      new_arr.local()->head = BCL::alloc<int>(1);
      *new_arr.local()->head.local() = 0;
      new_arr.local()->pos_in_queue =
          bclx::aget_sync(temp_tail).pos_in_queue + 1;
      bclx::gptr<segment_t> old_next =
          bclx::aget_sync(bclx::aget_sync(temp_tail).next);
      bclx::gptr<segment_t> result;
      bclx::compare_and_swap_sync(bclx::aget_sync(temp_tail).next, &old_next,
                                  &new_arr, &result);
      if (old_next == nullptr && result == old_next) {
        bclx::gptr<segment_t> tmp;
        bclx::compare_and_swap_sync(this->_tail_of_queue, &temp_tail, &new_arr,
                                    &tmp);
      } else {
        BCL::dealloc(new_arr.local()->curr_data_buffer);
        BCL::dealloc(new_arr);
      }
    }

    return true;
  }
};

// Warning: A little buggy when dequeuing from empty queue
template <typename T, int SEGMENT_SIZE = 32> class NaiveJiffyDequeuer {
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

  bclx::gptr<int> _tail;
  bclx::gptr<segment_t> _head_of_queue;
  bclx::gptr<bclx::gptr<segment_t>> _tail_of_queue;

public:
  NaiveJiffyDequeuer(int self_rank) {
    this->_tail = BCL::alloc<int>(1);
    *this->_tail = 0;

    this->_head_of_queue = BCL::alloc<segment_t>(1);

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
  }

  NaiveJiffyDequeuer(const NaiveJiffyDequeuer &) = delete;
  NaiveJiffyDequeuer &operator=(const NaiveJiffyDequeuer &) = delete;
  ~NaiveJiffyDequeuer() {
    // Just leak memory...
  }

  bool dequeue(T *output) {
    status_t status = bclx::aget_sync(
        bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
        bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));

    while (true) {
      bclx::gptr<segment_t> temp_tail = bclx::aget_sync(this->_tail_of_queue);
      unsigned int prev_size =
          SEGMENT_SIZE * (bclx::aget_sync(temp_tail).pos_in_queue - 1);
      if ((this->_head_of_queue == bclx::aget_sync(this->_tail_of_queue)) &&
          (bclx::aget_sync(bclx::aget_sync(this->_head_of_queue).head) ==
           bclx::aget_sync(this->_tail) - prev_size)) {
        return false;
      } else if (bclx::aget_sync(bclx::aget_sync(this->_head_of_queue).head) <
                 SEGMENT_SIZE) {
        status_t status = bclx::aget_sync(
            bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
            bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));
        T data = bclx::aget_sync(
            bclx::aget_sync(this->_head_of_queue).curr_data_buffer +
            bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));
        if (status == HANDLED) {
          int inc = 1;
          int tmp;
          bclx::fetch_and_op_sync(bclx::aget_sync(this->_head_of_queue).head,
                                  &inc, BCL::plus<int>{}, &tmp);
          continue;
        }

        bclx::gptr<segment_t> temp_head_of_queue = this->_head_of_queue;
        int temp_head =
            bclx::aget_sync(bclx::aget_sync(temp_head_of_queue).head);
        bool flag_move_to_new_buffer = false;
        bool flag_buffer_all_handled = true;
        while (status == EMPTY) {
          if (temp_head < SEGMENT_SIZE) {
            status_t t_status = bclx::aget_sync(
                bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
                temp_head);
            T t_data = bclx::aget_sync(
                bclx::aget_sync(this->_head_of_queue).curr_data_buffer +
                temp_head);
            ++temp_head;
            status = bclx::aget_sync(
                bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
                bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));

            if (t_status == SET && status == EMPTY) {
              bclx::gptr<segment_t> scan_head_of_queue = this->_head_of_queue;
              for (unsigned int scan_head = bclx::aget_sync(
                       bclx::aget_sync(scan_head_of_queue).head);
                   (scan_head_of_queue != temp_head_of_queue ||
                    scan_head < (temp_head - 1) && status == EMPTY);
                   ++scan_head) {
                if (scan_head >= SEGMENT_SIZE) {
                  scan_head_of_queue =
                      bclx::aget_sync(bclx::aget_sync(scan_head_of_queue).next);
                  scan_head =
                      bclx::aget_sync(bclx::aget_sync(scan_head_of_queue).head);

                  status = bclx::aget_sync(
                      bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
                      bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));
                  continue;
                }

                status_t scan_status = bclx::aget_sync(
                    bclx::aget_sync(scan_head_of_queue).curr_status_buffer +
                    scan_head);
                T scan_data = bclx::aget_sync(
                    bclx::aget_sync(scan_head_of_queue).curr_data_buffer +
                    scan_head);
                if (scan_status == SET) {
                  temp_head = scan_head;
                  temp_head_of_queue = scan_head_of_queue;
                  t_status = scan_status;
                  t_data = scan_data;

                  scan_head_of_queue = this->_head_of_queue;
                  scan_head =
                      bclx::aget_sync(bclx::aget_sync(scan_head_of_queue).head);
                }

                status = bclx::aget_sync(
                    bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
                    bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));
              }

              status = bclx::aget_sync(
                  bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
                  bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));

              if (status == SET) {
                break;
              }

              *output = t_data;
              bclx::aput_sync(
                  HANDLED,
                  bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
                      temp_head);
              if (flag_move_to_new_buffer &&
                  (temp_head - 1) ==
                      bclx::aget_sync(
                          bclx::aget_sync(temp_head_of_queue).head)) {
                int inc = 1;
                int tmp;
                bclx::fetch_and_op_sync(
                    bclx::aget_sync(temp_head_of_queue).head, &inc,
                    BCL::plus<int>{}, &tmp);
              }
              return true;
            }

            t_status = bclx::aget_sync(
                bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
                temp_head);
            if (t_status == EMPTY) {
              flag_buffer_all_handled = false;
            }
          }
          if (temp_head >= SEGMENT_SIZE) {
            if (flag_buffer_all_handled && flag_move_to_new_buffer) {
              if (temp_head_of_queue == bclx::aget_sync(this->_tail_of_queue)) {
                return false;
              }

              bclx::gptr<segment_t> next =
                  bclx::aget_sync(bclx::aget_sync(temp_head_of_queue).next);
              bclx::gptr<segment_t> prev =
                  bclx::aget_sync(bclx::aget_sync(temp_head_of_queue).prev);
              if (next == nullptr)
                return false;

              bclx::aput_sync(prev, bclx::aget_sync(next).prev);
              bclx::aput_sync(next, bclx::aget_sync(prev).next);
             //  BCL::dealloc(temp_head_of_queue);

              temp_head_of_queue = next;
              temp_head =
                  bclx::aget_sync(bclx::aget_sync(temp_head_of_queue).head);
              flag_buffer_all_handled = true;
              flag_move_to_new_buffer = true;
            } else {
              bclx::gptr<segment_t> next =
                  bclx::aget_sync(bclx::aget_sync(temp_head_of_queue).next);
              if (next == nullptr)
                return false;
              temp_head_of_queue = next;
              temp_head =
                  bclx::aget_sync(bclx::aget_sync(temp_head_of_queue).head);
              flag_buffer_all_handled = true;
              flag_move_to_new_buffer = true;
            }
          }
          status = bclx::aget_sync(
              bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
              bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));
        }
        status = bclx::aget_sync(
            bclx::aget_sync(this->_head_of_queue).curr_status_buffer +
            bclx::aget_sync(bclx::aget_sync(_head_of_queue).head));

        if (status == SET) {
          int inc = 1;
          int tmp;
          bclx::fetch_and_op_sync(bclx::aget_sync(this->_head_of_queue).head,
                                  &inc, BCL::plus<int>{}, &tmp);
          *output = data;
          return true;
        }
      }
      if (bclx::aget_sync(bclx::aget_sync(this->_head_of_queue).head) >=
          SEGMENT_SIZE) {
        if (this->_head_of_queue == bclx::aget_sync(_tail_of_queue))
          return false;

        bclx::gptr<segment_t> next =
            bclx::aget_sync(bclx::aget_sync(this->_head_of_queue).next);
        if (next == nullptr) {
          return false;
        }
        // BCL::dealloc(this->_head_of_queue);
        this->_head_of_queue = next;
      }
    }
  }
};
