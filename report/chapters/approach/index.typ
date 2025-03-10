= Approach <approach>

In this section, we discuss our general approach in porting shared memory MPSC algorithms to distributed context using MPI while still preserving their properties of lock-freedom.

As MPSC is an irregular application, MPI RMA is a necessity tool in our approach.

Our approach is an incremental approach, starting from pure MPI with MPI RMA, which can be used to easily port many shared memory algorithms, then progressively applying MPI-3 SHM and C++11 for improved intra-node communication.

== Pure MPI

In pure MPI, we use MPI exclusively for communication and synchronization. With MPI RMA, the communication calls that we utilize are:
- Remote read: `MPI_Get`
- Remote write: `MPI_Put`
- Remote accumulation: `MPI_Accumulate`, `MPI_Get_accumulate`, `MPI_Fetch_and_op` and `MPI_Compare_and_swap`.

For lock-free synchronization, we choose to use *passive target synchronization* with `MPI_Win_lock_all`/`MPI_Win_unlock_all`.

In the MPI-3 specification @mpi-3.1, these functions are specified as follows:

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Specification of `MPI_Win_lock_all` and `MPI_Win_unlock_all`],
  table(
    columns: (1fr, 2.5fr),
    table.header([*Operation*], [*Usage*]),
    [`MPI_Win_lock_all`],
    [Starts and RMA access epoch to all processes in a memory window, with a lock type of `MPI_LOCK_SHARED`. The calling process can access the window memory on all processes in the memory window using RMA operations. This routine is not collective.],

    [`MPI_Win_unlock_all`],
    [Matches with an `MPI_Win_lock_all` to unlock a window previously locked by that `MPI_Win_lock_all`.],
  ),
)

The reason we choose this is 3-fold:
- Unlike *active target synchronization*, *passive target synchronization* does not require the process whose memory is being accessed by an MPI RMA communication call to participate in. This is in line with our intention to use MPI RMA to easily model irregular applications like MPSCs.
- Unlike *active target synchronization*, `MPI_Win_lock_all` and `MPI_Win_unlock_all` do not need to wait for a matching synchronization call in the target process, and thus, is not delayed by the target process.
- Unlike *passive target synchronization* with `MPI_Win_lock`/`MPI_Win_unlock`, multiple calls of `MPI_Win_lock_all` can succeed concurrently, so one process needing to issue MPI RMA communication calls do not block others.

An example of our pure MPI approach with `MPI_Win_lock_all`/`MPI_Win_unlock_all`, inspired by @dinan, is illustrated in the following:

#figure(
  kind: "raw",
  supplement: "Listing",
  caption: "An example snippet showcasing our synchronization approach in MPI RMA",
  [
    ```cpp
    MPI_Win_lock_all(0, win);

    MPI_Get(...); // Remote get
    MPI_Put(...); // Remote put
    MPI_Accumulate(..., MPI_REPLACE, ...); // Atomic put
    MPI_Get_accumulate(..., MPI_NO_OP, ...); // Atomic get
    MPI_Fetch_and_op(...); // Remote fetch-and-op
    MPI_Compare_and_swap(...); // Remote compare and swap
    ...

    MPI_Win_flush(...); // Make previous RMA operations take effects
    MPI_Win_flush_local(...); // Make previous RMA operations take effects locally
    ...

    MPI_Win_unlock_all(win);
    ```
  ],
)

#figure(
  image("/static/images/mpi_win_lock_all.png"),
  caption: [An illustration of our synchronization approach in MPI RMA],
)

== MPI+MPI

As discussed in @background and @mpi-cpp, @zhou, a trend is to use MPI both for intra-node and inter-node communication. MPI-3 has introduced many improvements to MPI RMA to make this scheme feasible. Compared to pure MPI, MPI+MPI can be more efficient because the fact that some processes locating on the same node is exploited to improve communication.

The general approach is as follows:
1. `MPI_Comm_split_type` is used with `MPI_COMM_TYPE_SHARED` to split the communicator to shared-memory communicator.
2. `MPI_Win_allocate_shared` is called on each shared-memory communicator to obtain a shared-memory window.
3. Inside these shared-memory window, we can use other communication and synchronization primitives that are optimized for shared-memory context.

== MPI+MPI with C++11

As discussed in the previous section, we can use C++11 atomics and synchronization facilities inside shared-memory windows. As discussed in @mpi-cpp, this has the potential to obtain significant speedups compared to pure MPI.


In conclusion, our approach is to use pure MPI by default, MPI+MPI and C++11 are seen as optimization techniques.
