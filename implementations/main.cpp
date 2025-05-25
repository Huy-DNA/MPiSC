#define PROFILE 1

#ifdef PROFILE
#include <caliper/cali.h>
#endif

#include "./lib/benches/benchmarks/single-one-queue.hpp"
#include "./lib/benches/microbenchmarks/single-one-queue.hpp"
#include "./lib/benches/utils.h"
#include "./lib/comm.hpp"
#include "bcl/backends/mpi/backend.hpp"
#include <cstring>
#include <iostream>
#include <mpi.h>

void print_usage(const char *prog_name) {
  std::cout << "Usage: " << prog_name << " [option]\n"
            << "Options:\n"
            << "  rmo          - Run RMO latency report\n"
            << "  micro        - Run microbenchmarks\n"
            << "  bench        - Run benchmarks\n"
            << "  all          - Run everything (default if no option)\n"
            << "  help         - Show this help message\n";
}

int main(int argc, char **argv) {
  BCL::init();

  bool run_rmo = true;
  bool run_micro = true;
  bool run_bench = true;

  // Check command line arguments
  if (argc > 1) {
    if (std::strcmp(argv[1], "rmo") == 0) {
      run_micro = false;
      run_bench = false;
    } else if (std::strcmp(argv[1], "micro") == 0) {
      run_rmo = false;
      run_bench = false;
    } else if (std::strcmp(argv[1], "bench") == 0) {
      run_rmo = false;
      run_micro = false;
    } else if (std::strcmp(argv[1], "all") == 0) {
      // Default: run everything
    } else if (std::strcmp(argv[1], "help") == 0) {
      int rank;
      MPI_Comm_rank(MPI_COMM_WORLD, &rank);
      if (rank == 0) {
        print_usage(argv[0]);
      }
      MPI_Finalize();
      return 0;
    } else {
      int rank;
      MPI_Comm_rank(MPI_COMM_WORLD, &rank);
      if (rank == 0) {
        std::cout << "Unknown option: " << argv[1] << "\n";
        print_usage(argv[0]);
      }
      MPI_Finalize();
      return 1;
    }
  }

  // Execute selected operations
  if (run_rmo) {
    report_RMO_latency();
  }

  if (run_micro) {
    slotqueue_single_one_queue_microbenchmark(100000, 5);
    slotqueue_node_single_one_queue_microbenchmark(100000, 5);
    ltqueue_node_single_one_queue_microbenchmark(100000, 5);
    ltqueue_single_one_queue_microbenchmark(100000, 5);
    naive_jiffy_single_one_queue_microbenchmark(100000, 5);
    amqueue_single_one_queue_microbenchmark(100000, 5);
  }

  if (run_bench) {
    slotqueue_single_one_queue_benchmark(100000, 5);
    ltqueue_single_one_queue_benchmark(100000, 5);
  }

  BCL::finalize();
  return 0;
}
