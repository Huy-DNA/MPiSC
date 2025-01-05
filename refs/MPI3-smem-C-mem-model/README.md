# A novel MPI+MPI hybrid approach combining MPI-3 shared memory windows and C11/C++11 memory model

## Context

- MPI is widely used for *internode operations*.
- There's an increase of the number of cores in processors -> a rise for *intranode operations*.
- So there's a hybrid approach combining MPI for internode operations and shared memory for intranode operations. Why? To exploit the multicore in new processors and reduce bottleneck on network interfaces. Traditionally, there are other hybrid approaches like MPI+OpenMP or MPI+POSIX Threads, with OpenMP and POSIX Threads. Downsides: Share data among threads by default -> Hard-to-find bugs & Significant coordination efforts.
- MPI Remote Memory Access (RMA)'s introduction in MPI-2 and improvement in MPI-3 significantly improve MPI intranode communications. -> MPI+MPI hybrid using the "all memory is private unless explicitly shared" paradigm.
- Idea: Coupling MPI shared memory windows and C++11 synchronization.
  - The synchronization operations in MPI is slow, as it's made conservative of the hardware & platform.
  - Using the C++ memory model & its atomic data types & memory fences can lower synchronization costs compared to the MPI's equivalence. 
