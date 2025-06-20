#include <bclx/bclx.hpp>

#include "../ltqueue/ltqueue-unbounded.hpp"
#include "bcl/backends/mpi/backend.hpp"
#include <cstdio>
#include <mpi.h>

int main(int argc, char **argv) {
  BCL::init();
  int rank;
  int size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  if (rank == 0) {
    UnboundedLTQueue<int> queue(0, MPI_COMM_WORLD);
    for (int i = 0; i < 50; ++i) {
      if (!queue.enqueue(i)) {
        printf("Enqueue failed \n");
      }
    }
    MPI_Barrier(MPI_COMM_WORLD);
    for (int i = 0; i < 50 * size; ++i) {
      int value;
      if (queue.dequeue(&value)) {
        printf("dequeue %d\n", value);
      } else {
        printf("dequeue NULL\n");
      }
    }
  } else {
    UnboundedLTQueue<int> queue(0, MPI_COMM_WORLD);
    for (int i = 0; i < 50; ++i) {
      if (!queue.enqueue(i)) {
        printf("Enqueue failed \n");
      }
    }
    MPI_Barrier(MPI_COMM_WORLD);
  }

  BCL::finalize();
}
