#pragma once

#include "bcl/fastqueue.hpp"
#include "benches/utils.h"
#include "ltqueue/ltqueue.hpp"
#include "slot-queue/slot-queue.hpp"
#include <chrono>
#include <mpi.h>

inline void
slotqueue_single_one_queue_benchmark(unsigned long long number_of_elements,
                                     int iterations = 10) {
  int size;
  int rank;
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  unsigned long long elements_per_queue = number_of_elements / (size - 1) + 1;

  double total_enqueues = 0;
  double total_dequeues = 0;
  double total_successful_enqueues = 0;
  double total_successful_dequeues = 0;
  double total_microseconds = 0;
  double total_enqueues_microseconds = 0;
  double total_dequeues_microseconds = 0;
  double total_enqueues_latency_microseconds = 0;

  for (int i = 0; i < iterations; ++i) {
    double local_enqueues = 0;
    double local_dequeues = 0;
    double local_successful_enqueues = 0;
    double local_successful_dequeues = 0;
    double local_microseconds = 0;
    double local_enqueues_microseconds = 0;
    double local_dequeues_microseconds = 0;
    double workload_microseconds = 0;

    if (rank == 0) {
      SlotDequeuer<int> queue(elements_per_queue, rank, rank, MPI_COMM_WORLD);
      MPI_Barrier(MPI_COMM_WORLD);
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
          workload_microseconds += spin_wait(0.06);
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() -
          workload_microseconds;
      local_dequeues_microseconds = local_microseconds;
    } else {
      SlotEnqueuer<int> queue(elements_per_queue, 0, rank, MPI_COMM_WORLD);
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
          workload_microseconds += spin_wait(0.06);
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      MPI_Barrier(MPI_COMM_WORLD);
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
          workload_microseconds += spin_wait(0.06);
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count() -
          workload_microseconds;
      local_enqueues_microseconds = local_microseconds;
    }

    double enqueues = 0;
    double dequeues = 0;
    double successful_enqueues = 0;
    double successful_dequeues = 0;
    double microseconds = 0;
    double enqueues_microseconds = 0;
    double dequeues_microseconds = 0;
    double enqueues_latency_microseconds = 0;

    MPI_Allreduce(&local_dequeues, &dequeues, 1, MPI_DOUBLE, MPI_SUM,
                  MPI_COMM_WORLD);

    MPI_Allreduce(&local_enqueues, &enqueues, 1, MPI_DOUBLE, MPI_SUM,
                  MPI_COMM_WORLD);

    MPI_Allreduce(&local_successful_dequeues, &successful_dequeues, 1,
                  MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    MPI_Allreduce(&local_successful_enqueues, &successful_enqueues, 1,
                  MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    MPI_Allreduce(&local_microseconds, &microseconds, 1, MPI_DOUBLE, MPI_MAX,
                  MPI_COMM_WORLD);

    MPI_Allreduce(&local_enqueues_microseconds, &enqueues_microseconds, 1,
                  MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
    enqueues_microseconds /= size - 1;

    MPI_Allreduce(&local_enqueues_microseconds, &enqueues_latency_microseconds,
                  1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    MPI_Allreduce(&local_dequeues_microseconds, &dequeues_microseconds, 1,
                  MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);

    total_enqueues += enqueues;
    total_dequeues += dequeues;
    total_successful_dequeues += successful_dequeues;
    total_successful_enqueues += successful_enqueues;
    total_microseconds += microseconds;
    total_enqueues_microseconds += enqueues_microseconds;
    total_enqueues_latency_microseconds += enqueues_latency_microseconds;
    total_dequeues_microseconds += dequeues_microseconds;
  }

  report("Slotqueue", number_of_elements, iterations, total_microseconds,
         total_dequeues, total_successful_dequeues, total_dequeues_microseconds,
         total_enqueues, total_successful_enqueues, total_enqueues_microseconds,
         total_enqueues_latency_microseconds);
}

inline void
ltqueue_single_one_queue_benchmark(unsigned long long number_of_elements,
                                   int iterations = 10) {
  int size;
  int rank;
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  unsigned long long elements_per_queue = number_of_elements / (size - 1) + 1;

  double total_enqueues = 0;
  double total_dequeues = 0;
  double total_successful_enqueues = 0;
  double total_successful_dequeues = 0;
  double total_microseconds = 0;
  double total_enqueues_microseconds = 0;
  double total_dequeues_microseconds = 0;
  double total_enqueues_latency_microseconds = 0;

  for (int i = 0; i < iterations; ++i) {
    double local_enqueues = 0;
    double local_dequeues = 0;
    double local_successful_enqueues = 0;
    double local_successful_dequeues = 0;
    double local_microseconds = 0;
    double local_enqueues_microseconds = 0;
    double local_dequeues_microseconds = 0;
    double workload_microseconds = 0;

    if (rank == 0) {
      LTDequeuer<int> queue(elements_per_queue, rank, rank, MPI_COMM_WORLD);
      MPI_Barrier(MPI_COMM_WORLD);
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
          workload_microseconds += spin_wait(0.06);
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() -
          workload_microseconds;
      local_dequeues_microseconds = local_microseconds;
    } else {
      LTEnqueuer<int> queue(elements_per_queue, 0, rank, MPI_COMM_WORLD);
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
          workload_microseconds += spin_wait(0.06);
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      MPI_Barrier(MPI_COMM_WORLD);
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
          workload_microseconds += spin_wait(0.06);
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count() -
          workload_microseconds;
      local_enqueues_microseconds = local_microseconds;
    }

    double enqueues = 0;
    double dequeues = 0;
    double successful_enqueues = 0;
    double successful_dequeues = 0;
    double microseconds = 0;
    double enqueues_microseconds = 0;
    double dequeues_microseconds = 0;
    double enqueues_latency_microseconds = 0;

    MPI_Allreduce(&local_dequeues, &dequeues, 1, MPI_DOUBLE, MPI_SUM,
                  MPI_COMM_WORLD);

    MPI_Allreduce(&local_enqueues, &enqueues, 1, MPI_DOUBLE, MPI_SUM,
                  MPI_COMM_WORLD);

    MPI_Allreduce(&local_successful_dequeues, &successful_dequeues, 1,
                  MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    MPI_Allreduce(&local_successful_enqueues, &successful_enqueues, 1,
                  MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    MPI_Allreduce(&local_microseconds, &microseconds, 1, MPI_DOUBLE, MPI_MAX,
                  MPI_COMM_WORLD);

    MPI_Allreduce(&local_enqueues_microseconds, &enqueues_microseconds, 1,
                  MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
    enqueues_microseconds /= size - 1;

    MPI_Allreduce(&local_enqueues_microseconds, &enqueues_latency_microseconds,
                  1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    MPI_Allreduce(&local_dequeues_microseconds, &dequeues_microseconds, 1,
                  MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);

    total_enqueues += enqueues;
    total_dequeues += dequeues;
    total_successful_dequeues += successful_dequeues;
    total_successful_enqueues += successful_enqueues;
    total_microseconds += microseconds;
    total_enqueues_microseconds += enqueues_microseconds;
    total_enqueues_latency_microseconds += enqueues_latency_microseconds;
    total_dequeues_microseconds += dequeues_microseconds;
  }

  report("LTQueue", number_of_elements, iterations, total_microseconds,
         total_dequeues, total_successful_dequeues, total_dequeues_microseconds,
         total_enqueues, total_successful_enqueues, total_enqueues_microseconds,
         total_enqueues_latency_microseconds);
}
