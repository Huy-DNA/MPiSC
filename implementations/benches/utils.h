#pragma once
#include "comm.hpp"
#include <chrono>
#include <cstdio>
#include <mpi.h>
#include <string>

inline void report(const std::string &title,
                   unsigned long long number_of_elements, int iterations,
                   double microseconds, double dequeues,
                   double successful_dequeues, double dequeue_microseconds,
                   double enqueues, double successful_enqueues,
                   double enqueue_microseconds,
                   double enqueue_latency_microseconds) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  if (rank == 0) {
    printf("---- %s ----\n", title.c_str());
    printf("Dequeue latency: %g us\n",
           dequeue_microseconds / successful_dequeues);
    printf("Dequeue throughput: %g 10^5ops/s\n",
           successful_dequeues / dequeue_microseconds * 10);
    printf("Enqueue latency: %g us\n",
           enqueue_latency_microseconds / successful_enqueues);
    printf("Enqueue throughput: %g 10^5ops/s\n",
           successful_enqueues / enqueue_microseconds * 10);
    printf("Total throughput: %g 10^5ops/s\n",
           (successful_enqueues + successful_dequeues) / microseconds * 10);
  }
}

inline double spin_wait(double us) {
  auto t1 = std::chrono::high_resolution_clock::now();
  auto t2 = std::chrono::high_resolution_clock::now();
  while ((t2 - t1).count() / 1000.0 < us) {
    t2 = std::chrono::high_resolution_clock::now();
  }
  return (t2 - t1).count() / 1000.0;
}

inline void report_RMO_latency(unsigned int ops = 10000) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  int size;
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  MPI_Win win;
  int *ptr;
  MPI_Info info;
  MPI_Info_create(&info);
  MPI_Info_set(info, "same_disp_unit", "true");

  MPI_Win_allocate(rank != 0 ? 0 : sizeof(int), sizeof(int), info,
                   MPI_COMM_WORLD, &ptr, &win);

  double local_read_microseconds = 0;
  if (rank != 0) {
    for (int i = 0; i < ops; ++i) {
      int dst;
      auto t_0 = std::chrono::high_resolution_clock::now();
      read_sync(&dst, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_read_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
    }
    local_read_microseconds /= ops;
  }

  MPI_Win_flush_all(win);
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Win_flush_all(win);

  double local_write_microseconds = 0;
  if (rank != 0) {
    for (int i = 0; i < ops; ++i) {
      int src = rank;
      auto t_0 = std::chrono::high_resolution_clock::now();
      write_sync(&src, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_write_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
    }
    local_write_microseconds /= ops;
  }

  MPI_Win_flush_all(win);
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Win_flush_all(win);

  double local_atomic_read_microseconds = 0;
  if (rank != 0) {
    for (int i = 0; i < ops; ++i) {
      int dest;
      awrite_async(&rank, 0, 0, win); // create contention
      auto t_0 = std::chrono::high_resolution_clock::now();
      aread_sync(&dest, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_atomic_read_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
    }
    local_atomic_read_microseconds /= ops;
  }

  MPI_Win_flush_all(win);
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Win_flush_all(win);

  double local_atomic_write_microseconds = 0;
  if (rank != 0) {
    for (int i = 0; i < ops; ++i) {
      int src = rank;
      awrite_async(&rank, 0, 0, win); // create contention
      auto t_0 = std::chrono::high_resolution_clock::now();
      awrite_sync(&src, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_atomic_write_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
    }
    local_atomic_write_microseconds /= ops;
  }

  MPI_Win_flush_all(win);
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Win_flush_all(win);

  double local_faa_microseconds = 0;
  if (rank != 0) {
    for (int i = 0; i < ops; ++i) {
      int src = rank * 2;
      awrite_async(&src, 0, 0, win); // create contention

      int dst;
      auto t_0 = std::chrono::high_resolution_clock::now();
      fetch_and_add_sync(&dst, 1, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_faa_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
    }
    local_faa_microseconds /= ops;
  }

  MPI_Win_flush_all(win);
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Win_flush_all(win);

  double local_cas_microseconds = 0;
  if (rank != 0) {
    int old_val = 0;
    int new_val = rank;
    int result = 0;
    for (int i = 0; i < ops; ++i) {
      int src = rank * 2;
      awrite_async(&src, 0, 0, win); // create contention

      auto t_0 = std::chrono::high_resolution_clock::now();
      compare_and_swap_sync(&old_val, &new_val, &result, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_cas_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
      old_val = result;
    }
    local_cas_microseconds /= ops;
  }

  MPI_Win_flush_all(win);
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Win_flush_all(win);

  double read_microseconds;
  double atomic_read_microseconds;
  double write_microseconds;
  double atomic_write_microseconds;
  double faa_microseconds;
  double cas_microseconds;
  MPI_Allreduce(&local_read_microseconds, &read_microseconds, 1, MPI_DOUBLE,
                MPI_SUM, MPI_COMM_WORLD);
  MPI_Allreduce(&local_atomic_read_microseconds, &atomic_read_microseconds, 1,
                MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
  MPI_Allreduce(&local_write_microseconds, &write_microseconds, 1, MPI_DOUBLE,
                MPI_SUM, MPI_COMM_WORLD);
  MPI_Allreduce(&local_atomic_write_microseconds, &atomic_write_microseconds, 1,
                MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
  MPI_Allreduce(&local_faa_microseconds, &faa_microseconds, 1, MPI_DOUBLE,
                MPI_SUM, MPI_COMM_WORLD);
  MPI_Allreduce(&local_cas_microseconds, &cas_microseconds, 1, MPI_DOUBLE,
                MPI_SUM, MPI_COMM_WORLD);

  if (rank == 0) {
    printf("---- RMO latency ----\n");
    printf("Contending processes: %d\n", size - 1);
    printf("Read latency: %g us\n", read_microseconds / (size - 1));
    printf("Atomic read latency: %g us\n",
           atomic_read_microseconds / (size - 1));
    printf("Write latency: %g us\n", write_microseconds / (size - 1));
    printf("Atomic write latency: %g us\n",
           atomic_write_microseconds / (size - 1));
    printf("FAA latency: %g us\n", faa_microseconds / (size - 1));
    printf("CAS latency: %g us\n", cas_microseconds / (size - 1));
  }

  MPI_Win_free(&win);
}
