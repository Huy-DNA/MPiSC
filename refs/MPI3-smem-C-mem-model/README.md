# A novel MPI+MPI hybrid approach combining MPI-3 shared memory windows and C11/C++11 memory model

Link: https://www.sciencedirect.com/science/article/abs/pii/S074373152100143X

## Context

- MPI is widely used for *internode operations*.
- There's an increase of the number of cores in processors -> a rise for *intranode operations*.
- So there's a hybrid approach combining MPI for internode operations and shared memory for intranode operations. Why? To exploit the multicore in new processors and reduce bottleneck on network interfaces. Traditionally, there are other hybrid approaches like MPI+OpenMP or MPI+POSIX Threads, with OpenMP and POSIX Threads. Downsides: Share data among threads by default -> Hard-to-find bugs & Significant coordination efforts.
- MPI Remote Memory Access (RMA)'s introduction in MPI-2 and improvement in MPI-3 significantly improve MPI intranode communications. -> MPI+MPI hybrid using the "all memory is private unless explicitly shared" paradigm.
  - The MPI+MPI model is introduced in this paper: refhub.elsevier.com/S0743-7315(21)00143-X/bibC7EBCA568D8D14CDE37A39E8FD0C07D9s1
  - Shared memory was added as a functionality to the MPI RMA interfaces in MPI-3.
  - In this model:
    - `MPI_Comm_split_type` is used to group the ranks on one node together into a communicator.
    - `MPI_Win_allocate_shared` is used to create shared memory segments among nodes in the shared-memory communicator.
      - It's erroneous to call `MPI_Win_allocate_shared` on a communicator whose members cannot truly share memory.
    - The shared memory segment can be accessed/synchronized like traditional memory windows or can use load/store & other synchronization primitives.
- Idea: MPI+MPI with C++11 as the synchronization primitives within shared-memory.
  - MPI shared memory would be accessed with load/store.
  - Accesses to MPI shared memory are synchronized using C++11 synchronization primitives.
  - Motivation: C++11 synchronization primitives are very efficient.
