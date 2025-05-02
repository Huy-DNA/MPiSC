#include "../utils/distributed-counters/max-stutter.hpp"
#include <cstdio>
#include <iostream>
#include <mpi.h>

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  {
    MaxStutterCounter counter{0, 0, MPI_COMM_WORLD};
    if (rank != 0) {
      for (int i = 0; i < 5; ++i) {
        std::cout << i << ": " << counter.get_and_increment() << '\n';
      }
    }
  }

  MPI_Finalize();
}
