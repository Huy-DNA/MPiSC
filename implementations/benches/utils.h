#pragma once
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
    printf("Dequeue latency: %g ms\n",
           dequeue_microseconds / number_of_elements / iterations / 1000);
    printf("Dequeue throughput: %g ops/ms\n",
           successful_dequeues / dequeue_microseconds);
    printf("Enqueue latency: %g ms\n", enqueue_latency_microseconds /
                                           number_of_elements / iterations /
                                           1000);
    printf("Enqueue throughput: %g ops/ms\n",
           successful_enqueues / enqueue_microseconds);
    printf("Total throughput: %g ops/ms\n",
           (successful_enqueues + successful_dequeues) / microseconds);
  }
}
