#pragma once

#include "utils.hpp"
#include <algorithm>
#include <vector>

template <typename T, int SEGMENT_SIZE = 32> class hp {
private:
  typedef segment_t<T> segment_t;
  bclx::gptr<bclx::gptr<segment_t>> _reservations;
  std::vector<bclx::gptr<segment_t>> _reclaimed_list;
  std::vector<bclx::gptr<segment_t>> _freed_list;
  int _host;

  void _scan() {
    std::vector<bclx::gptr<segment_t>> list_temp;
    for (int i = 0; i < BCL::nprocs(); ++i) {
      bclx::gptr<segment_t> hp_val = bclx::aget_sync(this->_reservations + i);
      if (hp_val == nullptr) {
        continue;
      }
      list_temp.push_back(hp_val);
    }
    std::vector<bclx::gptr<segment_t>> reclaimed_list_temp;
    while (!this->_reclaimed_list.empty()) {
      bclx::gptr<segment_t> hp_val = this->_reclaimed_list.back();
      this->_reclaimed_list.pop_back();
      if (std::find(list_temp.begin(), list_temp.end(), hp_val) !=
          list_temp.end()) {
        reclaimed_list_temp.push_back(hp_val);
      } else {
        this->_freed_list.push_back(hp_val);
      }
    }
  }

public:
  hp(int host) : _host{host} {
    if (BCL::my_rank == _host) {
      this->_reservations = BCL::alloc<bclx::gptr<segment_t>>(BCL::nprocs());
      for (int i = 0; i < BCL::nprocs(); ++i) {
        bclx::aput_sync({0, 0}, this->_reservations + i);
      }
    }
    this->_reservations = BCL::broadcast(this->_reservations, host);
  }

  ~hp() {
    if (BCL::my_rank == _host) {
      BCL::dealloc(this->_reservations);
    }
  }

  bclx::gptr<segment_t> malloc() {
    if (this->_freed_list.size() > 0) {
      auto res = this->_freed_list.back();
      this->_freed_list.pop_back();
      return res;
    }
    return BCL::alloc<segment_t>(1);
  }

  void free(bclx::gptr<segment_t> ptr) {
    this->_reclaimed_list.push_back(ptr);
    if (this->_reclaimed_list.size() > 2 * BCL::nprocs()) {
      this->_scan();
    }
  }

  bclx::gptr<segment_t> reserve(bclx::gptr<bclx::gptr<segment_t>> ptr) {
    bclx::gptr<segment_t> old_val;
    bclx::gptr<segment_t> new_val;
    do {
      old_val = bclx::aget_sync(ptr);
      bclx::aput_sync(old_val, this->_reservations + BCL::my_rank);
      new_val = bclx::aget_sync(ptr);
    } while (old_val != new_val);
    return old_val;
  }
};
