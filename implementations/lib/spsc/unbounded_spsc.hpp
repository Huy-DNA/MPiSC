#pragma once

#include "../comm.hpp"

#include <bclx/bclx.hpp>

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

    for (int i = 0; i < BCL::nprocs(); ++i) {
      if (i == BCL::my_rank) {
        BCL::broadcast(dummy_node, i);
        BCL::broadcast(this->_first, 0);
        BCL::broadcast(this->_last, 0);
        BCL::broadcast(this->_free_later, 0);
        BCL::broadcast(this->_announce, 0);
        BCL::broadcast(this->_help, 0);
      } else {
        bclx::gptr<bclx::gptr<node_t>> tmp_1;
        bclx::gptr<node_t> tmp_2;
        BCL::broadcast(tmp_2, i);
        BCL::broadcast(tmp_1, 0);
        BCL::broadcast(tmp_1, 0);
        BCL::broadcast(tmp_1, 0);
        BCL::broadcast(tmp_1, 0);
        BCL::broadcast(tmp_2, 0);
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

    bclx::gptr<node_t> tmp = bclx::aget_sync(this->_last);
    tmp.local()->value = data;
    *tmp.local()->next.local() = new_node;

    bclx::aput_sync(new_node, this->_last);
    return true;
  }

  bool read_front(data_t *output) {
    bclx::gptr<node_t> tmp = bclx::aget_sync(this->_first);
    if (tmp == bclx::aget_sync(_last))
      return false;
    bclx::aput_sync(tmp, this->_announce);
    if (tmp != bclx::aget_sync(this->_first)) {
      *output = bclx::aget_sync(this->_help);
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
      bclx::gptr<node_t> dummy_node;
      BCL::broadcast(dummy_node, i);

      this->_first[i] = BCL::alloc<bclx::gptr<node_t>>(1);
      *this->_first[i].local() = dummy_node;

      this->_last[i] = BCL::alloc<bclx::gptr<node_t>>(1);
      *this->_last[i].local() = dummy_node;

      this->_free_later[i] = BCL::alloc<bclx::gptr<node_t>>(1);
      *this->_free_later[i].local() = BCL::alloc<node_t>(1);

      this->_announce[i] = BCL::alloc<bclx::gptr<node_t>>(1);
      *this->_announce[i].local() = nullptr;

      this->_help[i] = BCL::alloc<data_t>(1);

      this->_first[i] = BCL::broadcast(this->_first[i], 0);
      this->_last[i] = BCL::broadcast(this->_last[i], 0);
      this->_free_later[i] = BCL::broadcast(this->_free_later[i], 0);
      this->_announce[i] = BCL::broadcast(this->_announce[i], 0);
      this->_help[i] = BCL::broadcast(this->_help[i], 0);
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
