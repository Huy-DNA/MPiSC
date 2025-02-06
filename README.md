# Nonblocking distributed MPSC queues using the hybrid programing model combining MPI-3 and C++11

## Objective

- Examination of the *shared-memory* literature to find potential *lock-free*, *concurrent*, *multiple-producer single-consumer* queue algorithms.
- Use the hybrid programming model MPI+MPI with C++11 for shared-memory synchronization to port the potential *shared-memory* queue algorithm to distributed context.

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

<details>
  <summary>Hybrid MPI+MPI approach with C++11 memory model?</summary>
  TBU
</details>

<details>
  <summary>C++11 memory model</summary>
  TBU
</details>

<details>
  <summary>How to perform an MPI port in a lock-free manner?</summary>
  TBU
</details>

<details>
  <summary>General porting approach?</summary>
  TBU
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

  Possible solutions: Dummy node to decouple head and tail ([JP-Queue](/refs/JP-Queue/README.md) and [Imp-Lfq](/refs/Imp-Lfq/README.md)).

- A slow process performing `enqueue` and `dequeue` could leave the queue in an intermediate state.

  Possible solutions: To be lockfree, the other processes can help out patching up the queue (don't wait).

- A dead process performing `enqueue` and `dequeue` could leave the queue broken.
  
  Possible solutions: The other processes can help out patching up the queue (help mechanism).

- Patching up the queue (help mechanism)?

  Why: If `enqueue` or `dequeue` needs to perform some updates on the queue to move it to a consistent state, then a suspended process may leave the queue in an intermediate state. The `enqueue` and `dequeue` should not wait until it sees a consistent state or else the algorithm is blocking. Rather, they should help the suspended process complete the operation.

  Possible solutions: (1) detect intermediate state. (2) (try) patch.
  1. Typically, updates are performed using CAS. If CAS fails, some state changes have occurred, we can detect if this is intermediary & try to perform another CAS to patch up the queue. Note that the patching CAS may fail in case the queue is just patched up, so looping until a successful CAS may not be necessary. A good example can be found in [`enqueue` operation in Imp-Lfq pp.3](/refs/Imp-Lfq/README.md)

### Trends

- Speed up happy paths.
  - WFQueue: The happy path uses lock-free algorithm and falls back to the wait-free algorithm. As lock-free algorithms are typically more efficient, this can lead to speedups.
  - Replacing CAS with simpler operations like FAA, load/store in the fast path.
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
- Scalability: The performance gain for `queue` and `enqueue` should scale with the number of threads on the target platform.

### Scalability
- Lock-free-ness: A thread suspended while using the queue should not prevent other threads from making progress using the queue.
