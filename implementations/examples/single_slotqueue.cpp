#include "../slotqueue/slotqueue.hpp"
#include <cstdio>
#include <mpi.h>

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);
  int rank;
  int size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  if (rank == 0) {
    SlotQueue<int> queue(1000, rank, rank, MPI_COMM_WORLD);
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
    SlotQueue<int> queue(1000, 0, rank, MPI_COMM_WORLD);
    for (int i = 0; i < 50; ++i) {
      if (!queue.enqueue(i)) {
        printf("Enqueue failed \n");
      }
    }
    MPI_Barrier(MPI_COMM_WORLD);
  }

  MPI_Finalize();
}
