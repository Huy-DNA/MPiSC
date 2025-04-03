#pragma once
#include "comm.hpp"
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <string>

inline void cache_flush() {
  static constexpr uint64_t bigger_than_cachesize = 100 * 1024 * 1024;
  static volatile long p[bigger_than_cachesize];
  for (int i = 0; i < bigger_than_cachesize; ++i) {
    p[i] = rand();
  }
}

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

inline void report_RMO_latency(unsigned int ops = 1000) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  int size;
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  MPI_Info info;
  MPI_Info_create(&info);
  MPI_Info_set(info, "same_disp_unit", "true");

  double local_atomic_read_microseconds = 0;
  for (int i = 0; i < ops; ++i) {
    MPI_Win win;
    int *ptr;
    MPI_Win_allocate(rank != 0 ? 0 : sizeof(int), sizeof(int), info,
                     MPI_COMM_WORLD, &ptr, &win);
    if (rank != 0) {
      int dest;
      awrite_async(&rank, 0, 0, win); // create contention
      auto t_0 = std::chrono::high_resolution_clock::now();
      aread_sync(&dest, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_atomic_read_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
    }
    MPI_Win_free(&win);
  }
  local_atomic_read_microseconds /= ops;

  double local_atomic_write_microseconds = 0;
  for (int i = 0; i < ops; ++i) {
    MPI_Win win;
    int *ptr;
    MPI_Win_allocate(rank != 0 ? 0 : sizeof(int), sizeof(int), info,
                     MPI_COMM_WORLD, &ptr, &win);
    if (rank != 0) {
      int src = rank * i;
      awrite_async(&rank, 0, 0, win); // create contention
      auto t_0 = std::chrono::high_resolution_clock::now();
      awrite_sync(&src, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_atomic_write_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
    }
    MPI_Win_free(&win);
  }
  local_atomic_write_microseconds /= ops;

  double local_faa_microseconds = 0;
  for (int i = 0; i < ops; ++i) {
    MPI_Win win;
    int *ptr;
    MPI_Win_allocate(rank != 0 ? 0 : sizeof(int), sizeof(int), info,
                     MPI_COMM_WORLD, &ptr, &win);
    if (rank != 0) {
      int src = rank * i;
      awrite_async(&src, 0, 0, win); // create contention
      int dst;
      auto t_0 = std::chrono::high_resolution_clock::now();
      fetch_and_add_sync(&dst, 1, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_faa_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
    }
    MPI_Win_free(&win);
  }
  local_faa_microseconds /= ops;

  double local_cas_microseconds = 0;
  for (int i = 0; i < ops; ++i) {
    MPI_Win win;
    int *ptr;
    MPI_Win_allocate(rank != 0 ? 0 : sizeof(int), sizeof(int), info,
                     MPI_COMM_WORLD, &ptr, &win);
    if (rank != 0) {
      int old_val = 0;
      int new_val = rank;
      int result = 0;
      int src = rank * i;
      awrite_async(&src, 0, 0, win); // create contention
      auto t_0 = std::chrono::high_resolution_clock::now();
      compare_and_swap_sync(&old_val, &new_val, &result, 0, 0, win);
      auto t_1 = std::chrono::high_resolution_clock::now();
      local_cas_microseconds +=
          std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
              .count();
      old_val = result;
    }
    MPI_Win_free(&win);
  }
  local_cas_microseconds /= ops;

  double atomic_read_microseconds;
  double atomic_write_microseconds;
  double faa_microseconds;
  double cas_microseconds;
  MPI_Allreduce(&local_atomic_read_microseconds, &atomic_read_microseconds, 1,
                MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
  MPI_Allreduce(&local_atomic_write_microseconds, &atomic_write_microseconds, 1,
                MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
  MPI_Allreduce(&local_faa_microseconds, &faa_microseconds, 1, MPI_DOUBLE,
                MPI_SUM, MPI_COMM_WORLD);
  MPI_Allreduce(&local_cas_microseconds, &cas_microseconds, 1, MPI_DOUBLE,
                MPI_SUM, MPI_COMM_WORLD);

  if (rank == 0) {
    printf("---- RMO latency ----\n");
    printf("Contending processes: %d\n", size - 1);
    printf("Atomic read latency: %g us\n",
           atomic_read_microseconds / (size - 1));
    printf("Atomic write latency: %g us\n",
           atomic_write_microseconds / (size - 1));
    printf("FAA latency: %g us\n", faa_microseconds / (size - 1));
    printf("CAS latency: %g us\n", cas_microseconds / (size - 1));
  }

  MPI_Info_free(&info);
}
