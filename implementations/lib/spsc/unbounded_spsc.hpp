#pragma once

#include <bclx/bclx.hpp>
#include <mpi.h>

#include "bcl/backends/mpi/backend.hpp"
#include "bcl/backends/mpi/comm.hpp"
#include "bcl/core/alloc.hpp"
#include "bcl/core/teams.hpp"
#include "bclx/core/comm.hpp"
#include "bclx/core/definition.hpp"

// Warning: Dequeuer cannot self-enqueue just yet!
template <typename data_t> class UnboundedSpsc {
  int _self_rank;
  const MPI_Aint _dequeuer_rank;

  struct node_t {
    data_t value;
    bclx::gptr<bclx::gptr<node_t>> next;
  };

  bclx::gptr<bclx::gptr<node_t>> _e_first;
  bclx::gptr<bclx::gptr<node_t>> *_d_first;
  bclx::gptr<bclx::gptr<node_t>> _e_last;
  bclx::gptr<bclx::gptr<node_t>> *_d_last;
  bclx::gptr<node_t> *_d_last_cached;
  bclx::gptr<bclx::gptr<node_t>> _e_announce;
  bclx::gptr<bclx::gptr<node_t>> *_d_announce;
  bclx::gptr<bclx::gptr<node_t>> _e_free_later;
  bclx::gptr<bclx::gptr<node_t>> *_d_free_later;
  bclx::gptr<data_t> _e_help;
  bclx::gptr<data_t> *_d_help;

public:
  UnboundedSpsc(MPI_Aint dequeuer_rank, MPI_Comm comm)
      : _dequeuer_rank{dequeuer_rank} {
    MPI_Comm_rank(comm, &this->_self_rank);
    if (this->_self_rank == this->_dequeuer_rank) {
      this->_d_first = new bclx::gptr<bclx::gptr<node_t>>[BCL::nprocs()];
      this->_d_last = new bclx::gptr<bclx::gptr<node_t>>[BCL::nprocs()];
      this->_d_last_cached = new bclx::gptr<node_t>[BCL::nprocs()];
      this->_d_announce = new bclx::gptr<bclx::gptr<node_t>>[BCL::nprocs()];
      this->_d_free_later = new bclx::gptr<bclx::gptr<node_t>>[BCL::nprocs()];
      this->_d_help = new bclx::gptr<data_t>[BCL::nprocs()];

      for (int i = 0; i < BCL::nprocs(); ++i) {
        bclx::gptr<node_t> dummy_node;
        BCL::broadcast(dummy_node, i);

        this->_d_first[i] = BCL::alloc<bclx::gptr<node_t>>(1);
        *this->_d_first[i].local() = dummy_node;

        this->_d_free_later[i] = BCL::alloc<bclx::gptr<node_t>>(1);
        *this->_d_free_later[i].local() = BCL::alloc<node_t>(1);

        this->_d_announce[i] = BCL::alloc<bclx::gptr<node_t>>(1);
        *this->_d_announce[i].local() = nullptr;

        this->_d_help[i] = BCL::alloc<data_t>(1);

        this->_d_first[i] = BCL::broadcast(this->_d_first[i], 0);
        this->_d_last[i] = BCL::broadcast(this->_d_last[i], i);
        this->_d_last_cached[i] = dummy_node;
        this->_d_free_later[i] = BCL::broadcast(this->_d_free_later[i], 0);
        this->_d_announce[i] = BCL::broadcast(this->_d_announce[i], 0);
        this->_d_help[i] = BCL::broadcast(this->_d_help[i], 0);
      }

    } else {
      bclx::gptr<node_t> dummy_node = BCL::alloc<node_t>(1);
      dummy_node.local()->next = BCL::alloc<bclx::gptr<node_t>>(1);
      *dummy_node.local()->next.local() = nullptr;

      this->_e_last = BCL::alloc<bclx::gptr<node_t>>(1);
      *this->_e_last.local() = dummy_node;

      for (int i = 0; i < BCL::nprocs(); ++i) {
        if (i == BCL::my_rank) {
          BCL::broadcast(dummy_node, i);
          BCL::broadcast(this->_e_first, 0);
          BCL::broadcast(this->_e_last, i);
          BCL::broadcast(this->_e_free_later, 0);
          BCL::broadcast(this->_e_announce, 0);
          BCL::broadcast(this->_e_help, 0);
        } else {
          bclx::gptr<bclx::gptr<node_t>> tmp_1;
          bclx::gptr<node_t> tmp_2;
          BCL::broadcast(tmp_2, i);
          BCL::broadcast(tmp_1, 0);
          BCL::broadcast(tmp_1, i);
          BCL::broadcast(tmp_1, 0);
          BCL::broadcast(tmp_1, 0);
          BCL::broadcast(tmp_2, 0);
        }
      }
    }
  }

  ~UnboundedSpsc() {
    // free later
  }

  bool enqueue(const data_t &data) {
    bclx::gptr<node_t> new_node = BCL::alloc<node_t>(1);
    new_node.local()->next = BCL::alloc<bclx::gptr<node_t>>(1);
    *new_node.local()->next.local() = nullptr;

    bclx::gptr<node_t> tmp = bclx::aget_sync(this->_e_last);
    tmp.local()->value = data;
    *tmp.local()->next.local() = new_node;

    bclx::aput_sync(new_node, this->_e_last);
    return true;
  }

  bool e_read_front(data_t *output) {
    bclx::gptr<node_t> tmp = bclx::aget_sync(this->_e_first);
    if (tmp == bclx::aget_sync(_e_last))
      return false;
    bclx::aput_sync(tmp, this->_e_announce);
    if (tmp != bclx::aget_sync(this->_e_first)) {
      *output = bclx::aget_sync(this->_e_help);
    } else {
      *output = tmp.local()->value;
    }
    return true;
  }

  bool dequeue(data_t *output, int enqueuer_rank) {
    bclx::gptr<node_t> tmp = bclx::aget_sync(this->_d_first[enqueuer_rank]);
    if (tmp == this->_d_last_cached[enqueuer_rank]) {
      this->_d_last_cached[enqueuer_rank] =
          bclx::aget_sync(this->_d_last[enqueuer_rank]);
      if (tmp == this->_d_last_cached[enqueuer_rank]) {
        return false;
      }
    }
    node_t tmp_node = bclx::aget_sync(tmp);
    *output = tmp_node.value;
    bclx::aput_sync(*output, this->_d_help[enqueuer_rank]);
    bclx::aput_sync(bclx::aget_sync(tmp_node.next),
                    this->_d_first[enqueuer_rank]);
    if (tmp == bclx::aget_sync(this->_d_announce[enqueuer_rank])) {
      bclx::gptr<node_t> another_tmp =
          bclx::aget_sync(this->_d_free_later[enqueuer_rank]);
      bclx::aput_sync(tmp, this->_d_free_later[enqueuer_rank]);
      // BCL::dealloc(another_tmp);
    } else {
      // BCL::dealloc(tmp);
    }
    return true;
  }

  bool d_read_front(data_t *output, int enqueuer_rank) {
    bclx::gptr<node_t> tmp = bclx::aget_sync(this->_d_first[enqueuer_rank]);
    if (tmp == this->_d_last_cached[enqueuer_rank]) {
      this->_d_last_cached[enqueuer_rank] =
          bclx::aget_sync(this->_d_last[enqueuer_rank]);
      if (tmp == this->_d_last_cached[enqueuer_rank]) {
        return false;
      }
    }
    node_t tmp_node = bclx::aget_sync(tmp);
    *output = tmp_node.value;
    return true;
  }
};
