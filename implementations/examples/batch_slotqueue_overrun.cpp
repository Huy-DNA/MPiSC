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
    SlotDequeuer<int> queue(25, 0, rank, MPI_COMM_WORLD);
    for (int i = 0; i < 1000; ++i) {
      int value;
      if (queue.dequeue(&value)) {
        printf("dequeue %d\n", value);
      }
    }
  } else {
    SlotEnqueuer<int> queue(25, 0, rank, MPI_COMM_WORLD);
    std::vector<int> buffer;
    for (int i = 0; i < 60; ++i) {
      buffer.push_back(i);
      if (buffer.size() == 20) {
        while (!queue.enqueue(buffer))
          ;
        buffer.clear();
      }
    }
  }

  MPI_Finalize();
}
