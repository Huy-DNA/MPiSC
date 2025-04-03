#define PROFILE 1

#include "benches/utils.h"
#include "benches/benchmarks/single-one-queue.hpp"
#include "benches/microbenchmarks/single-one-queue.hpp"
#include <caliper/cali.h>
#include <comm.hpp>
#include <ltqueue/ltqueue.hpp>
#include <mpi.h>

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);

  slotqueue_single_one_queue_microbenchmark(100000, 5);
  slotqueueV2_single_one_queue_microbenchmark(100000, 5);
  ltqueue_single_one_queue_microbenchmark(100000, 5);
  fastqueue_single_one_queue_microbenchmark(100000, 5);

  slotqueue_single_one_queue_benchmark(100000, 5);
  ltqueue_single_one_queue_benchmark(100000, 5);
  fastqueue_single_one_queue_benchmark(100000, 5);

  MPI_Finalize();
}
