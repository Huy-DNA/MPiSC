#include <bcl/bcl.hpp>
#include <comm.hpp>
#include <ltqueue/ltqueue.hpp>
#include <mpi.h>

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);

  MPI_Finalize();
}
