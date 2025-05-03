#include "../active-message-queue/active-message-queue.hpp"
#include <cstdio>
#include <mpi.h>
#include <vector>

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);
  int rank;
  int size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  if (rank == 0) {
    AMDequeuer<int> queue(1000, rank, rank, MPI_COMM_WORLD);
    MPI_Barrier(MPI_COMM_WORLD);
    for (int i = 0; i < 50 * (size - 1); ++i) {
      std::vector<int> values;
      if (queue.dequeue(values)) {
        for (int value : values) {
          printf("dequeue %d\n", value);
        }
      } else {
        printf("dequeue NULL\n");
      }
    }
  } else {
    AMEnqueuer<int> queue(1000, 0, rank, MPI_COMM_WORLD);
    for (int i = 0; i < 50; ++i) {
      if (!queue.enqueue(i)) {
        printf("Enqueue failed \n");
      }
    }
    MPI_Barrier(MPI_COMM_WORLD);
  }

  MPI_Finalize();
}
