#pragma once
#include "../comm.hpp"
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <random>
#include <vector>

inline double spin_wait(double us) {
  auto t1 = std::chrono::high_resolution_clock::now();
  auto t2 = std::chrono::high_resolution_clock::now();
  while ((t2 - t1).count() / 1000.0 < us) {
    t2 = std::chrono::high_resolution_clock::now();
  }
  return (t2 - t1).count() / 1000.0;
}

inline void report_RMO_latency_all_to_one(unsigned int ops = 1000) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  int size;
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  MPI_Info info;
  MPI_Info_create(&info);
  MPI_Info_set(info, "same_disp_unit", "true");
  MPI_Info_set(info, "accumulate_ordering", "none");

  double local_atomic_read_microseconds = 0;
  double local_atomic_write_microseconds = 0;
  double local_faa_microseconds = 0;
  double local_cas_microseconds = 0;

  enum OpType { READ, WRITE, FAA, CAS };
  std::vector<OpType> operations;
  operations.reserve(ops * 4);

  for (unsigned int i = 0; i < ops; ++i) {
    operations.push_back(READ);
    operations.push_back(WRITE);
    operations.push_back(FAA);
    operations.push_back(CAS);
  }

  std::random_device rd;
  std::mt19937 gen(rd());
  std::shuffle(operations.begin(), operations.end(), gen);

  for (unsigned int i = 0; i < operations.size(); ++i) {
    OpType current_op = operations[i];

    MPI_Win win;
    int *ptr;
    MPI_Win_allocate(rank != 0 ? 0 : sizeof(int), sizeof(int), info,
                     MPI_COMM_WORLD, &ptr, &win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, win);

    if (rank != 0) {
      switch (current_op) {
      case READ: {
        int dest;
        auto t_0 = std::chrono::high_resolution_clock::now();
        aread_sync(&dest, 0, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_atomic_read_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case WRITE: {
        int src = rank * i;
        auto t_0 = std::chrono::high_resolution_clock::now();
        awrite_sync(&src, 0, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_atomic_write_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case FAA: {
        int dst;
        auto t_0 = std::chrono::high_resolution_clock::now();
        fetch_and_add_sync(&dst, 1, 0, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_faa_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case CAS: {
        int old_val = 0;
        int new_val = rank;
        int result = 0;
        auto t_0 = std::chrono::high_resolution_clock::now();
        compare_and_swap_sync(&old_val, &new_val, &result, 0, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_cas_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        old_val = result;
        break;
      }
      }
    }

    MPI_Win_unlock_all(win);
    MPI_Win_free(&win);
  }

  local_atomic_read_microseconds /= ops;
  local_atomic_write_microseconds /= ops;
  local_faa_microseconds /= ops;
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
    printf("---- RMO latency - all-to-one ----\n");
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

inline void report_RMO_latency_single(unsigned int ops = 1000) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  int size;
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  MPI_Info info;
  MPI_Info_create(&info);
  MPI_Info_set(info, "same_disp_unit", "true");
  MPI_Info_set(info, "accumulate_ordering", "none");

  double local_atomic_read_microseconds = 0;
  double local_atomic_write_microseconds = 0;
  double local_faa_microseconds = 0;
  double local_cas_microseconds = 0;

  enum OpType { READ, WRITE, FAA, CAS };
  std::vector<OpType> operations;
  operations.reserve(ops * 4);

  for (unsigned int i = 0; i < ops; ++i) {
    operations.push_back(READ);
    operations.push_back(WRITE);
    operations.push_back(FAA);
    operations.push_back(CAS);
  }

  std::random_device rd;
  std::mt19937 gen(rd());
  std::shuffle(operations.begin(), operations.end(), gen);

  for (unsigned int i = 0; i < operations.size(); ++i) {
    OpType current_op = operations[i];

    MPI_Win win;
    int *ptr;
    MPI_Win_allocate(rank != 0 ? 0 : sizeof(int), sizeof(int), info,
                     MPI_COMM_WORLD, &ptr, &win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, win);

    if (rank != 0) {
      switch (current_op) {
      case READ: {
        int dest;
        auto t_0 = std::chrono::high_resolution_clock::now();
        if (rank == size - 1)
          aread_sync(&dest, 0, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_atomic_read_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case WRITE: {
        int src = rank * i;
        auto t_0 = std::chrono::high_resolution_clock::now();
        if (rank == size - 1)
          awrite_sync(&src, 0, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_atomic_write_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case FAA: {
        int dst;
        auto t_0 = std::chrono::high_resolution_clock::now();
        if (rank == size - 1)
          fetch_and_add_sync(&dst, 1, 0, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_faa_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case CAS: {
        int old_val = 0;
        int new_val = rank;
        int result = 0;
        auto t_0 = std::chrono::high_resolution_clock::now();
        if (rank == size - 1)
          compare_and_swap_sync(&old_val, &new_val, &result, 0, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_cas_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        old_val = result;
        break;
      }
      }
    }

    MPI_Win_unlock_all(win);
    MPI_Win_free(&win);
  }

  local_atomic_read_microseconds /= ops;
  local_atomic_write_microseconds /= ops;
  local_faa_microseconds /= ops;
  local_cas_microseconds /= ops;

  double atomic_read_microseconds;
  double atomic_write_microseconds;
  double faa_microseconds;
  double cas_microseconds;
  MPI_Allreduce(&local_atomic_read_microseconds, &atomic_read_microseconds, 1,
                MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);
  MPI_Allreduce(&local_atomic_write_microseconds, &atomic_write_microseconds, 1,
                MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);
  MPI_Allreduce(&local_faa_microseconds, &faa_microseconds, 1, MPI_DOUBLE,
                MPI_MAX, MPI_COMM_WORLD);
  MPI_Allreduce(&local_cas_microseconds, &cas_microseconds, 1, MPI_DOUBLE,
                MPI_MAX, MPI_COMM_WORLD);

  if (rank == 0) {
    printf("---- RMO latency - single ----\n");
    printf("#processes: %d\n", size - 1);
    printf("Atomic read latency: %g us\n", atomic_read_microseconds);
    printf("Atomic write latency: %g us\n", atomic_write_microseconds);
    printf("FAA latency: %g us\n", faa_microseconds);
    printf("CAS latency: %g us\n", cas_microseconds);
  }

  MPI_Info_free(&info);
}

inline void report_RMO_latency_all_to_all(unsigned int ops = 1000) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  int size;
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  MPI_Info info;
  MPI_Info_create(&info);
  MPI_Info_set(info, "same_disp_unit", "true");
  MPI_Info_set(info, "accumulate_ordering", "none");

  double local_atomic_read_microseconds = 0;
  double local_atomic_write_microseconds = 0;
  double local_faa_microseconds = 0;
  double local_cas_microseconds = 0;

  enum OpType { READ, WRITE, FAA, CAS };
  std::vector<OpType> operations;
  operations.reserve(ops * 4);

  for (unsigned int i = 0; i < ops; ++i) {
    operations.push_back(READ);
    operations.push_back(WRITE);
    operations.push_back(FAA);
    operations.push_back(CAS);
  }

  std::random_device rd;
  std::mt19937 gen(rd());
  std::shuffle(operations.begin(), operations.end(), gen);

  for (unsigned int i = 0; i < operations.size(); ++i) {
    OpType current_op = operations[i];

    MPI_Win win;
    int *ptr;
    MPI_Win_allocate(rank != 0 ? 0 : size * sizeof(int), sizeof(int), info,
                     MPI_COMM_WORLD, &ptr, &win);
    MPI_Win_lock_all(MPI_MODE_NOCHECK, win);

    if (rank != 0) {
      switch (current_op) {
      case READ: {
        int dest;
        auto t_0 = std::chrono::high_resolution_clock::now();
        aread_sync(&dest, rank, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_atomic_read_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case WRITE: {
        int src = rank * i;
        auto t_0 = std::chrono::high_resolution_clock::now();
        awrite_sync(&src, rank, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_atomic_write_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case FAA: {
        int dst;
        auto t_0 = std::chrono::high_resolution_clock::now();
        fetch_and_add_sync(&dst, 1, rank, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_faa_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        break;
      }

      case CAS: {
        int old_val = 0;
        int new_val = rank;
        int result = 0;
        auto t_0 = std::chrono::high_resolution_clock::now();
        compare_and_swap_sync(&old_val, &new_val, &result, rank, 0, win);
        auto t_1 = std::chrono::high_resolution_clock::now();
        local_cas_microseconds +=
            std::chrono::duration_cast<std::chrono::microseconds>(t_1 - t_0)
                .count();
        old_val = result;
        break;
      }
      }
    }

    MPI_Win_unlock_all(win);
    MPI_Win_free(&win);
  }

  local_atomic_read_microseconds /= ops;
  local_atomic_write_microseconds /= ops;
  local_faa_microseconds /= ops;
  local_cas_microseconds /= ops;

  double atomic_read_microseconds;
  double atomic_write_microseconds;
  double faa_microseconds;
  double cas_microseconds;
  MPI_Allreduce(&local_atomic_read_microseconds, &atomic_read_microseconds, 1,
                MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);
  MPI_Allreduce(&local_atomic_write_microseconds, &atomic_write_microseconds, 1,
                MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);
  MPI_Allreduce(&local_faa_microseconds, &faa_microseconds, 1, MPI_DOUBLE,
                MPI_MAX, MPI_COMM_WORLD);
  MPI_Allreduce(&local_cas_microseconds, &cas_microseconds, 1, MPI_DOUBLE,
                MPI_MAX, MPI_COMM_WORLD);

  if (rank == 0) {
    printf("---- RMO latency - all-to-all ----\n");
    printf("#processes: %d\n", size - 1);
    printf("Atomic read latency: %g us\n", atomic_read_microseconds);
    printf("Atomic write latency: %g us\n", atomic_write_microseconds);
    printf("FAA latency: %g us\n", faa_microseconds);
    printf("CAS latency: %g us\n", cas_microseconds);
  }

  MPI_Info_free(&info);
}
