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
