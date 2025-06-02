#pragma once

#include "../../active-message-queue/active-message-queue.hpp"
#include "../../jiffy/naive-jiffy.hpp"
#include "../../ltqueue/ltqueue-node.hpp"
#include "../../ltqueue/ltqueue-unbounded.hpp"
#include "../../ltqueue/ltqueue.hpp"
#include "../../slotqueue/slotqueue-node.hpp"
#include "../../slotqueue/slotqueue-unbounded.hpp"
#include "../../slotqueue/slotqueue.hpp"
#include "bcl/backends/mpi/backend.hpp"
#include "bcl/backends/mpi/comm.hpp"
#include "bcl/core/teams.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <mpi.h>
#include <string>

static void report_isx(std::string title, unsigned long long number_of_elements,
                       int iterations, double total_microseconds) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  if (rank == 0) {
    printf("---- %s ----\n", title.c_str());
    printf("Average latency: %g us\n", total_microseconds / number_of_elements);
  }
}

inline void slotqueue_isx_sort(unsigned long long number_of_elements,
                               int iterations = 10) {
  std::vector<SlotQueue<int>> queues;
  for (size_t rank = 0; rank < BCL::nprocs(); rank++) {
    queues.push_back(SlotQueue<int>(number_of_elements, rank, MPI_COMM_WORLD));
  }

  double microseconds = 0;

  const int MAX_NUM = 10000000;
  const int slice_size = 1 + MAX_NUM / BCL::nprocs();

  auto t1 = std::chrono::high_resolution_clock::now();
  for (int _ = 0; _ < iterations; ++_) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> distr(0, MAX_NUM);

    for (unsigned long long _ = 0; _ < number_of_elements; ++_) {
      int num = distr(gen);
      int slice_index = num / slice_size;
      queues[slice_index].enqueue(num);
    }

    BCL::barrier();
    int output;
    std::vector<int> my_keys;
    while (queues[BCL::my_rank].dequeue(&output)) {
      my_keys.push_back(output);
    }
    std::sort(my_keys.begin(), my_keys.end());
    BCL::barrier();
  }
  auto t2 = std::chrono::high_resolution_clock::now();
  double local_microseconds =
      std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1).count();

  MPI_Allreduce(&local_microseconds, &microseconds, 1, MPI_DOUBLE, MPI_MAX,
                MPI_COMM_WORLD);

  report_isx("Slotqueue", number_of_elements, iterations, microseconds);
}
