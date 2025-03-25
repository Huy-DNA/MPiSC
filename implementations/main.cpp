#include "benches/microbenchmarks/single-one-queue.hpp"
#include "benches/microbenchmarks/batch-one-queue.hpp"
#include <comm.hpp>
#include <ltqueue/ltqueue.hpp>
#include <mpi.h>

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);

  slotqueue_batch_one_queue_microbenchmark(1000000, 1000);
  ltqueue_batch_one_queue_microbenchmark(1000000, 1000);
  fastqueue_batch_one_queue_microbenchmark(1000000, 1000);

  MPI_Finalize();
}
