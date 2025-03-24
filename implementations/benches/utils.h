#pragma once
#include <cstdio>
#include <mpi.h>
#include <string>

inline void report(const std::string &title,
                   unsigned long long number_of_elements, int iterations,
                   double microseconds, double dequeues,
                   double successful_dequeues, double dequeue_microseconds,
                   double enqueues, double successful_enqueues,
                   double enqueue_microseconds) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  if (rank == 0) {
    printf("---- %s ----\n", title.c_str());
    printf("Total iterations: %d \n", iterations);
    printf("Mean running time: %g ms\n", microseconds / iterations / 1000);
    printf("Mean dequeues: %g ops\n", dequeues / iterations);
    printf("Mean successful dequeues: %g ops\n",
           successful_dequeues / iterations);
    printf("Mean dequeue running time: %g ms\n",
           dequeue_microseconds / iterations / 1000);
    printf("Mean enqueues: %g ops\n", enqueues / iterations);
    printf("Mean successful enqueues: %g ops\n",
           successful_enqueues / iterations);
    printf("Mean enqueue running time: %g ms\n",
           enqueue_microseconds / iterations / 1000);
  }
}
