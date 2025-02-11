# Porting shared memory MPSCs to distributed computing using MPI-3 RMA

## Objective

- Examination of the *shared-memory* literature to find potential *lock-free*, *concurrent*, *multiple-producer single-consumer* queue algorithms.
- Use the an MPI-3 new RMA capabilities to port potential lock-free *shared-memory* queue algorithms to distributed context.
- Potentially optimize MPI RMA ports using MPI-3 SHM + C++11 memory model. 

- Minimum characteristics:

| Dimension           | Desired property        |
| ------------------- | ----------------------- |
| Queue length        | Fixed length            |
| Number of producers | Many                    |
| Number of consumers | One                     |
| Operations          | `queue`, `enqueue`      |
| Concurrency         | Concurrent & Lock-free  |

## Motivation

- Queue is the backbone data structures in many applications: scheduling, event handling, message bufferring. In these applications, the queue may be highly contended, for example, in event handling, there can be multiple sources of events & many consumers of events at the same time. If the queue has not been designed properly, it can become a bottleneck in a highly concurrent environment, adversely affecting the application's scalability. This sentiment also applies to queues in distributed contexts.
- Within the context of shared-memory, there have been plenty of research and testing going into efficient, scalable & lock-free queue algorithms. This presents an opportunity to port these high-quality algorithms to the distributed context, albeit some inherent differences that need to be taken into consideration between the two contexts.
- In the distributed literature, most of the proposed algorithms completely disregard the existing shared-memory algorithms. This is why we investigate the porting approach & compare them with existing distributed queue algorithms.

## Approach

The porting approach we choose is to use MPI-3 RMA to port lock-free queue algorithms. We further optimize these ports using MPI SHM (or the so called MPI+MPI hybrid approach) and C++11 for shared memory synchronization.

<details>
  <summary>Why MPI RMA?</summary>
  
  MPSC belongs to the class of *irregular* applications, this means that:
    - Memory access pattern is not known.
    - Data locations cannot be known in advance, it can change during execution.
  
  In other words, we cannot statically analyze where the data may be stored - data can be stored anywhere and we can only determine its location at runtime. This means the tradition message passing interface using `MPI_Send` and `MPI_Recv` is insufficient: Suppose at runtime, process A wants and knows to access a piece of data at `B`, then `A` must issue `MPI_Recv(B)`, but this requires `B` to anticipate that it should issue `MPI_Send(A, data)` and know that which data `A` actually wants. The latter issue can be worked around by having `A` issue `MPI_Send(B, data_descripto)` first. Then, `B` must have waited for `MPI_Recv(A)`. However, because the memory access pattern is not known, `B` must anticipate that any other processes may want to access its data. It's possible but cumbersome.
   
   MPI RMA is specifically designed to conveniently express irregular applications by having one side specify all it wants.

</details>

<details>
  <summary>Why MPI-3 RMA? ([paper](/refs/MPI3-RMA/README.md))</summary>

  MPI-3 improves the RMA API, providing the non-collective `MPI_Win_lock_all` for a process to open an access epoch on a group of processes. This allows for lock-free synchronization.
</details>

<details>
  <summary>Hybrid MPI+MPI ([paper](/refs/MPI%2BMPI/README.md))</summary>
  The Pure MPI approach is oblivious to the fact that some MPI processes are on the same node, which causes some unnecessary overhead. MPI-3 introduces the MPI SHM API, allowing us to obtain a communicator containing processes on a single node. From this communicator, we can allocate a shared memory window using `MPI_Win_allocate_shared`. Hybrid MPI+MPI means that MPI is used for both intra-node and inter-node communication. This shared memory window follows the *unified memory model* and can be synchronized both using MPI facilities or any other alternatives. Hybrid MPI+MPI can take advantage of the many cores of current computer processors.
</details>

<details>
  <summary>Hybrid MPI+MPI+C++11 ([paper](/refs/MPI%2BMPI%2BCpp11/README.md))</summary>
  Within the shared memory window, C++11 synchronization facilities can be used and prove to be much more efficient than MPI. So incorporating C++11 can be thought of as an optimization step for intra-node communication.
</details>

<details>
  <summary>How to perform an MPI port in a lock-free manner?</summary>
  
  With MPI-3 RMA capabilities:
    - Use `MPI_Win_lock_all` and `MPI_Win_unlock_all` to open and end access epochs.
    - Within an access epoch, MPI atomics are used.
  
  This is made clear in [MPI3-RMA](/refs/MPI3-RMA/README.md).
</details>

## Literature review

### Links
- [References](/refs/README.md): Notes for various related papers.

### Known problems
- ABA problem.

  Possible solutions: Monotonic counter, hazard pointer.

- Safe memory reclamation problem.

  Possible solutions: Hazard pointer.

- Special case: empty queue - Concurrent `enqueue` and `dequeue` can conflict with each other.

  Possible solutions: Dummy node to decouple head and tail ([LTQueue](/refs/LT-Queue/README.md) and [Imp-Lfq](/refs/Imp-Lfq/README.md)).

- A slow process performing `enqueue` and `dequeue` could leave the queue in an intermediate state.

  Possible solutions:
  - Help mechanism (introduced in [MSQueue](/refs/MSQueue/README.md)): To be lockfree, the other processes can help out patching up the queue (don't wait).

- A dead process performing `enqueue` and `dequeue` could leave the queue broken.
  
  Possible solutions:
  - Help mechanism (introduced in [MSQueue](/refs/MSQueue/README.md)): The other processes can help out patching up the queue.

- Motivation for the help mechanism?

  Why: If `enqueue` or `dequeue` needs to perform some updates on the queue to move it to a consistent state, then a suspended process may leave the queue in an intermediate state. The `enqueue` and `dequeue` should not wait until it sees a consistent state or else the algorithm is blocking. Rather, they should help the suspended process complete the operation.

  Solutions often involve (1) detecting intermediate state (2) trying to patch.

  Possible solutions:
  - Typically, updates are performed using CAS. If CAS fails, some state changes have occurred, we can detect if this is intermediary & try to perform another CAS to patch up the queue.
    Note that the patching CAS may fail in case the queue is just patched up, so looping until a successful CAS may not be necessary.
    A good example can be found in [the `enqueue` operation in Imp-Lfq pp.3](/refs/Imp-Lfq/README.md)

### Trends

- Speed up happy paths.
  - The happy path can use lock-free algorithm and fall back to the wait-free algorithm. As lock-free algorithms are typically more efficient, this can lead to speedups.
  - Replacing CAS with simpler operations like FAA, load/store in the fast path ([WFQueue](/refs/WFQueue/README.md)).
- Avoid contention: Enqueuers or dequeuers performing on a shared data structures can harm each other's progress.
  - Local buffers can be used at the enqueuers' side in MPSC so that enqueuers do not contend with each other.
  - Elimination + Backing off techniques in MPMC.
- Cache-aware solutions.

## Evaluation strategy

We need to evaluate at least 3 levels:
- Theory verification: Prove that the algorithm possesses the desired properties.
- Implementation verification: Even though theory is correct, implementation details nuances can affect the desired properties.
  - Static verification: *Verify* the source code + its dependencies.
  - Dynamic verification: *Verify* its behavior at runtime & *Benchmark*.

### Correctness
- Correctness: Correct `queue`/`enqueue` semantics, memory-safe, no undefined-behavior.
<details>
  <summary>Caution - Lockfree-ness of dependencies</summary>
  A lock-free algorithm often *assumes* that some synchronization primitive is lock-free. This depends on the target platform and during implementation, the library used. Care must be taken to avoid accidental non-lock-free operation usage.
</details>

### Performance
- Performance: The less time it takes to serve common workloads on the target platform the better.

### Lockfree-ness
- Lock-free-ness: A process suspended while using the queue should not prevent other processes from making progress using the queue.

### Scalability
- Scalability: The performance gain for `queue` and `enqueue` should scale with the number of threads on the target platform.
