#pragma once

#include "../comm.hpp"

#include <bclx/bclx.hpp>
#include <iostream>
#include <ostream>

#include "bcl/backends/mpi/backend.hpp"
#include "bcl/backends/mpi/comm.hpp"
#include "bcl/core/alloc.hpp"
#include "bcl/core/teams.hpp"
#include "bclx/core/comm.hpp"
#include "bclx/core/definition.hpp"

template <typename data_t> class UnboundedSpscEnqueuer {
  const MPI_Aint _self_rank;
  const MPI_Aint _dequeuer_rank;

  struct node_t {
    data_t value;
    bclx::gptr<bclx::gptr<node_t>> next;
  };

  bclx::gptr<bclx::gptr<node_t>> _first;
  bclx::gptr<bclx::gptr<node_t>> _last;
  bclx::gptr<bclx::gptr<node_t>> _announce;
  bclx::gptr<bclx::gptr<node_t>> _free_later;
  bclx::gptr<data_t> _help;

public:
  UnboundedSpscEnqueuer(MPI_Aint self_rank, MPI_Aint dequeuer_rank,
                        MPI_Comm comm)
      : _self_rank{self_rank}, _dequeuer_rank{dequeuer_rank} {
    bclx::gptr<node_t> dummy_node = BCL::alloc<node_t>(1);
    dummy_node.local()->next = BCL::alloc<bclx::gptr<node_t>>(1);
    *dummy_node.local()->next.local() = nullptr;

    this->_first = BCL::alloc<bclx::gptr<node_t>>(1);
    *this->_first.local() = dummy_node;

    this->_last = BCL::alloc<bclx::gptr<node_t>>(1);
    *this->_last.local() = dummy_node;

    this->_free_later = BCL::alloc<bclx::gptr<node_t>>(1);
    *this->_free_later.local() = BCL::alloc<node_t>(1);

    this->_announce = BCL::alloc<bclx::gptr<node_t>>(1);
    *this->_announce.local() = nullptr;

    this->_help = BCL::alloc<data_t>(1);

    for (int i = 0; i < BCL::nprocs(); ++i) {
      if (i == BCL::my_rank) {
        BCL::broadcast(this->_first, i);
        BCL::broadcast(this->_last, i);
        BCL::broadcast(this->_free_later, i);
        BCL::broadcast(this->_announce, i);
        BCL::broadcast(this->_help, i);
      } else {
        bclx::gptr<bclx::gptr<node_t>> tmp_1;
        bclx::gptr<node_t> tmp_2;
        BCL::broadcast(tmp_1, i);
        BCL::broadcast(tmp_1, i);
        BCL::broadcast(tmp_1, i);
        BCL::broadcast(tmp_1, i);
        BCL::broadcast(tmp_2, i);
      }
    }
  }

  ~UnboundedSpscEnqueuer() {
    // free later
  }

  bool enqueue(const data_t &data) {
    bclx::gptr<node_t> new_node = BCL::alloc<node_t>(1);
    new_node.local()->next = BCL::alloc<bclx::gptr<node_t>>(1);
    *new_node.local()->next.local() = nullptr;

    bclx::gptr<node_t> tmp = *this->_last.local();
    tmp.local()->value = data;
    *tmp.local()->next.local() = new_node;

    *this->_last.local() = new_node;
    return true;
  }

  bool read_front(data_t *output) {
    bclx::gptr<node_t> tmp = *_first.local();
    if (tmp == *_last.local())
      return false;
    *this->_announce.local() = tmp;
    if (tmp != *_first.local()) {
      *output = *_help.local();
    } else {
      *output = tmp.local()->value;
    }
    return true;
  }
};

template <typename data_t> class UnboundedSpscDequeuer {
  const MPI_Aint _self_rank;

  struct node_t {
    data_t value;
    bclx::gptr<bclx::gptr<node_t>> next;
  };

  bclx::gptr<bclx::gptr<node_t>> *_first;
  bclx::gptr<bclx::gptr<node_t>> *_last;
  bclx::gptr<bclx::gptr<node_t>> *_announce;
  bclx::gptr<bclx::gptr<node_t>> *_free_later;
  bclx::gptr<data_t> *_help;

public:
  UnboundedSpscDequeuer(MPI_Aint self_rank, MPI_Comm comm)
      : _self_rank{self_rank} {
    this->_first = new bclx::gptr<bclx::gptr<node_t>>[BCL::nprocs()];
    this->_last = new bclx::gptr<bclx::gptr<node_t>>[BCL::nprocs()];
    this->_announce = new bclx::gptr<bclx::gptr<node_t>>[BCL::nprocs()];
    this->_free_later = new bclx::gptr<bclx::gptr<node_t>>[BCL::nprocs()];
    this->_help = new bclx::gptr<data_t>[BCL::nprocs()];

    for (int i = 0; i < BCL::nprocs(); ++i) {
      this->_first[i] = BCL::broadcast(this->_first[i], i);
      this->_last[i] = BCL::broadcast(this->_last[i], i);
      this->_free_later[i] = BCL::broadcast(this->_free_later[i], i);
      this->_announce[i] = BCL::broadcast(this->_announce[i], i);
      this->_help[i] = BCL::broadcast(this->_help[i], i);
    }
  }

  ~UnboundedSpscDequeuer() {
    // free later
  }

  bool dequeue(data_t *output, int enqueuer_rank) {
    bclx::gptr<node_t> tmp = bclx::aget_sync(this->_first[enqueuer_rank]);
    if (tmp == bclx::aget_sync(this->_last[enqueuer_rank])) {
      return false;
    }
    node_t tmp_node = bclx::aget_sync(tmp);
    *output = tmp_node.value;
    bclx::aput_sync(*output, this->_help[enqueuer_rank]);
    bclx::aput_sync(bclx::aget_sync(tmp_node.next),
                    this->_first[enqueuer_rank]);
    if (tmp == bclx::aget_sync(this->_announce[enqueuer_rank])) {
      bclx::gptr<node_t> another_tmp =
          bclx::aget_sync(this->_free_later[enqueuer_rank]);
      bclx::aput_sync(tmp, this->_free_later[enqueuer_rank]);
      // BCL::dealloc(another_tmp);
    } else {
      // BCL::dealloc(tmp);
    }
    return true;
  }

  bool read_front(data_t *output, int enqueuer_rank) {
    bclx::gptr<node_t> tmp = bclx::aget_sync(this->_first[enqueuer_rank]);
    if (tmp == bclx::aget_sync(this->_last[enqueuer_rank])) {
      return false;
    }
    node_t tmp_node = bclx::aget_sync(tmp);
    *output = tmp_node.value;
    return true;
  }
};
