#include "benches/benchmarks/single-one-queue.hpp"
#include "benches/microbenchmarks/single-one-queue.hpp"
#include <caliper/cali.h>
#include <comm.hpp>
#include <ltqueue/ltqueue.hpp>
#include <mpi.h>

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);

  slotqueue_single_one_queue_microbenchmark(1000000);
  ltqueue_single_one_queue_microbenchmark(1000000);
  fastqueue_single_one_queue_microbenchmark(1000000);

  slotqueue_single_one_queue_benchmark(1000000);
  ltqueue_single_one_queue_benchmark(1000000);
  fastqueue_single_one_queue_benchmark(1000000);

  MPI_Finalize();
}
