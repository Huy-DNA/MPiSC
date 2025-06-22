#define PROFILE 1

#ifdef PROFILE
#include <caliper/cali.h>
#endif

#include "./lib/benches/microbenchmarks/single-one-queue-overflow.hpp"
#include "./lib/benches/microbenchmarks/single-one-queue.hpp"
#include "./lib/benches/utils.h"
#include "bcl/backends/mpi/backend.hpp"
#include "lib/benches/apps/isx/mpsc-isx.hpp"
#include <cstring>
#include <iostream>
#include <mpi.h>

void print_usage(const char *prog_name) {
  std::cout << "Usage: " << prog_name << " [option]\n"
            << "Options:\n"
            << "  rmo          - Run RMO latency report\n"
            << "  micro        - Run microbenchmarks\n"
            << "  bench        - Run benchmarks\n"
            << "  isx          - Run ISx latency report\n"
            << "  all          - Run everything (default if no option)\n"
            << "  help         - Show this help message\n";
}

int main(int argc, char **argv) {
  BCL::init();

  bool run_rmo = true;
  bool run_micro = true;
  bool run_bench = true;
  bool run_isx = true;

  // Check command line arguments
  if (argc > 1) {
    if (std::strcmp(argv[1], "rmo") == 0) {
      run_micro = false;
      run_bench = false;
      run_isx = false;
    } else if (std::strcmp(argv[1], "micro") == 0) {
      run_rmo = false;
      run_bench = false;
      run_isx = false;
    } else if (std::strcmp(argv[1], "bench") == 0) {
      run_rmo = false;
      run_micro = false;
      run_isx = false;
    } else if (std::strcmp(argv[1], "isx") == 0) {
      run_rmo = false;
      run_micro = false;
      run_bench = false;
    } else if (std::strcmp(argv[1], "all") == 0) {
      // Default: run everything
    } else if (std::strcmp(argv[1], "help") == 0) {
      int rank;
      MPI_Comm_rank(MPI_COMM_WORLD, &rank);
      if (rank == 0) {
        print_usage(argv[0]);
      }
      BCL::finalize();
      return 0;
    } else {
      int rank;
      MPI_Comm_rank(MPI_COMM_WORLD, &rank);
      if (rank == 0) {
        std::cout << "Unknown option: " << argv[1] << "\n";
        print_usage(argv[0]);
      }
      BCL::finalize();
      return 1;
    }
  }

  // Execute selected operations
  if (run_rmo) {
    report_RMO_latency();
  }

  if (run_micro) {
    // hosted_slotqueue_single_one_queue_overflow_microbenchmark(100000, 5);
    amqueue_single_one_queue_overflow_microbenchmark(10000, 5);
  }

  if (run_isx) {
    slotqueue_isx_sort(100000000, 1, true);
    ltqueue_isx_sort(100000000, 1, true);
  }

  if (run_bench) {
  }

  BCL::finalize();
  return 0;
}
