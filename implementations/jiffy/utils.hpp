#pragma once

#include <bclx/bclx.hpp>

#include <cstdlib>
#include <mpi.h>

enum status_t {
  SET,
  HANDLED,
  EMPTY,
};

template <typename T> struct segment_t {
  bclx::gptr<T> curr_data_buffer;
  bclx::gptr<status_t> curr_status_buffer;
  bclx::gptr<bclx::gptr<segment_t>> next;
  bclx::gptr<bclx::gptr<segment_t>> prev;
  bclx::gptr<int> head;
  int pos_in_queue;
};

template <typename T>
void fully_reclaim_segment(bclx::gptr<segment_t<T>> segment) {
  BCL::dealloc(segment.local()->curr_data_buffer);
  BCL::dealloc(segment.local()->curr_status_buffer);
  BCL::dealloc(segment.local()->next);
  BCL::dealloc(segment.local()->prev);
  BCL::dealloc(segment.local()->head);
  BCL::dealloc(segment);
}
