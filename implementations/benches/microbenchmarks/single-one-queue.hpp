#pragma once

#include "bcl/fastqueue.hpp"
#include "benches/utils.h"
#include "caliper/cali_macros.h"
#include "ltqueue/ltqueue.hpp"
#include "slot-queue/slot-queue-v2a.hpp"
#include "slot-queue/slot-queue-v2b.hpp"
#include "slot-queue/slot-queue-v2bc.hpp"
#include "slot-queue/slot-queue-v2c.hpp"
#include "slot-queue/slot-queue.hpp"
#include <caliper/cali.h>
#include <chrono>
#include <mpi.h>

inline void
slotqueue_single_one_queue_microbenchmark(unsigned long long number_of_elements,
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

    if (rank == 0) {
      CALI_MARK_BEGIN("slot-dequeuer-init-1");
      SlotDequeuer<int> queue(elements_per_queue, rank, rank, MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-init-1");
      CALI_MARK_BEGIN("slot-dequeuer-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-init-2");
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count();
      local_dequeues_microseconds = local_microseconds;
    } else {
      CALI_MARK_BEGIN("slot-enqueuer-init-1");
      SlotEnqueuer<int> queue(elements_per_queue, 0, rank, MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-init-1");
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      CALI_MARK_BEGIN("slot-enqueuer-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-init-2");
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count();
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

inline void slotqueueV2a_single_one_queue_microbenchmark(
    unsigned long long number_of_elements, int iterations = 10) {
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

    if (rank == 0) {
      CALI_MARK_BEGIN("slot-dequeuer-v2a-init-1");
      SlotDequeuerV2a<int> queue(elements_per_queue, rank, rank,
                                 MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-v2a-init-1");
      CALI_MARK_BEGIN("slot-dequeuer-v2a-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-v2a-init-2");
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count();
      local_dequeues_microseconds = local_microseconds;
    } else {
      CALI_MARK_BEGIN("slot-enqueuer-v2a-init-1");
      SlotEnqueuerV2a<int> queue(elements_per_queue, 0, rank, MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-v2a-init-1");
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      CALI_MARK_BEGIN("slot-enqueuer-v2a-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-v2a-init-2");
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count();
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

  report("SlotqueueV2a", number_of_elements, iterations, total_microseconds,
         total_dequeues, total_successful_dequeues, total_dequeues_microseconds,
         total_enqueues, total_successful_enqueues, total_enqueues_microseconds,
         total_enqueues_latency_microseconds);
}

inline void slotqueueV2b_single_one_queue_microbenchmark(
    unsigned long long number_of_elements, int iterations = 10) {
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

    if (rank == 0) {
      CALI_MARK_BEGIN("slot-dequeuer-v2b-init-1");
      SlotDequeuerV2b<int> queue(elements_per_queue, rank, rank,
                                 MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-v2b-init-1");
      CALI_MARK_BEGIN("slot-dequeuer-v2b-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-v2b-init-2");
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count();
      local_dequeues_microseconds = local_microseconds;
    } else {
      CALI_MARK_BEGIN("slot-enqueuer-v2b-init-1");
      SlotEnqueuerV2b<int> queue(elements_per_queue, 0, rank, MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-v2b-init-1");
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      CALI_MARK_BEGIN("slot-enqueuer-v2b-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-v2b-init-2");
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count();
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

  report("SlotqueueV2b", number_of_elements, iterations, total_microseconds,
         total_dequeues, total_successful_dequeues, total_dequeues_microseconds,
         total_enqueues, total_successful_enqueues, total_enqueues_microseconds,
         total_enqueues_latency_microseconds);
}

inline void slotqueueV2c_single_one_queue_microbenchmark(
    unsigned long long number_of_elements, int iterations = 10) {
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

    if (rank == 0) {
      CALI_MARK_BEGIN("slot-dequeuer-v2c-init-1");
      SlotDequeuerV2c<int> queue(elements_per_queue, rank, rank,
                                 MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-v2c-init-1");
      CALI_MARK_BEGIN("slot-dequeuer-v2c-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-v2c-init-2");
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count();
      local_dequeues_microseconds = local_microseconds;
    } else {
      CALI_MARK_BEGIN("slot-enqueuer-v2c-init-1");
      SlotEnqueuerV2c<int> queue(elements_per_queue, 0, rank, MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-v2c-init-1");
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      CALI_MARK_BEGIN("slot-enqueuer-v2c-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-v2c-init-2");
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count();
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

  report("SlotqueueV2c", number_of_elements, iterations, total_microseconds,
         total_dequeues, total_successful_dequeues, total_dequeues_microseconds,
         total_enqueues, total_successful_enqueues, total_enqueues_microseconds,
         total_enqueues_latency_microseconds);
}

inline void slotqueueV2bc_single_one_queue_microbenchmark(
    unsigned long long number_of_elements, int iterations = 10) {
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

    if (rank == 0) {
      CALI_MARK_BEGIN("slot-dequeuer-v2bc-init-1");
      SlotDequeuerV2bc<int> queue(elements_per_queue, rank, rank,
                                 MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-v2bc-init-1");
      CALI_MARK_BEGIN("slot-dequeuer-v2bc-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-dequeuer-v2bc-init-2");
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count();
      local_dequeues_microseconds = local_microseconds;
    } else {
      CALI_MARK_BEGIN("slot-enqueuer-v2bc-init-1");
      SlotEnqueuerV2bc<int> queue(elements_per_queue, 0, rank, MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-v2bc-init-1");
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      CALI_MARK_BEGIN("slot-enqueuer-v2bc-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("slot-enqueuer-v2bc-init-2");
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count();
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

  report("SlotqueueV2bc", number_of_elements, iterations, total_microseconds,
         total_dequeues, total_successful_dequeues, total_dequeues_microseconds,
         total_enqueues, total_successful_enqueues, total_enqueues_microseconds,
         total_enqueues_latency_microseconds);
}

inline void
ltqueue_single_one_queue_microbenchmark(unsigned long long number_of_elements,
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

    if (rank == 0) {
      CALI_MARK_BEGIN("lt-dequeuer-init-1");
      LTDequeuer<int> queue(elements_per_queue, rank, rank, MPI_COMM_WORLD);
      CALI_MARK_END("lt-dequeuer-init-1");
      CALI_MARK_BEGIN("lt-dequeuer-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("lt-dequeuer-init-2");
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count();
      local_dequeues_microseconds = local_microseconds;
    } else {
      CALI_MARK_BEGIN("lt-enqueuer-init-1");
      LTEnqueuer<int> queue(elements_per_queue, 0, rank, MPI_COMM_WORLD);
      CALI_MARK_END("lt-enqueuer-init-1");
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      CALI_MARK_BEGIN("lt-enqueuer-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("lt-enqueuer-init-2");
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count();
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

inline void
fastqueue_single_one_queue_microbenchmark(unsigned long long number_of_elements,
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

    if (rank == 0) {
      CALI_MARK_BEGIN("fast-dequeuer-init-1");
      FastDequeuer<int> queue(number_of_elements, rank, rank, MPI_COMM_WORLD);
      CALI_MARK_END("fast-dequeuer-init-1");
      CALI_MARK_BEGIN("fast-dequeuer-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("fast-dequeuer-init-2");
      auto t1 = std::chrono::high_resolution_clock::now();
      while (local_successful_dequeues < number_of_elements) {
        int output;
        if (queue.dequeue(&output)) {
          ++local_dequeues;
          ++local_successful_dequeues;
        } else {
          ++local_dequeues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count();
      local_dequeues_microseconds = local_microseconds;
    } else {
      CALI_MARK_BEGIN("fast-enqueuer-init-1");
      FastEnqueuer<int> queue(number_of_elements, 0, rank, MPI_COMM_WORLD);
      CALI_MARK_END("fast-enqueuer-init-1");
      int warm_up_elements = 5;
      auto t1 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < warm_up_elements; ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t2 = std::chrono::high_resolution_clock::now();
      CALI_MARK_BEGIN("fast-enqueuer-init-2");
      MPI_Barrier(MPI_COMM_WORLD);
      CALI_MARK_END("fast-enqueuer-init-2");
      auto t3 = std::chrono::high_resolution_clock::now();
      for (unsigned long long i = 0; i < elements_per_queue - warm_up_elements;
           ++i) {
        if (queue.enqueue(i)) {
          ++local_enqueues;
          ++local_successful_enqueues;
        } else {
          ++local_enqueues;
        }
      }
      auto t4 = std::chrono::high_resolution_clock::now();
      local_microseconds =
          std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1)
              .count() +
          std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3)
              .count();
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

  report("FastQueue", number_of_elements, iterations, total_microseconds,
         total_dequeues, total_successful_dequeues, total_dequeues_microseconds,
         total_enqueues, total_successful_enqueues, total_enqueues_microseconds,
         total_enqueues_latency_microseconds);
}
