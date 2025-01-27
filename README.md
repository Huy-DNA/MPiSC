# Nonblocking distributed MPSC queues using the hybrid programing model combining MPI-3 and C++11

## Objective

- Examination of the *shared-memory* literature to find potential *lock-free*, *concurrent*, *multiple-producer single-consumer* queue algorithms.
- Use the hybrid programming model MPI+MPI with C++11 for shared-memory synchronization to port the potential *shared-memory* queue algorithm to distributed context.

## Motivation

- Queue is the backbone data structures in many applications: scheduling, event handling, message bufferring. In these applications, the queue may be highly contended, for example, in event handling, there can be multiple sources of events & many consumers of events at the same time. If the queue has not been designed properly, it can become a bottleneck in a highly concurrent environment, adversely affecting the application's scalability. This sentiment also applies to queues in distributed contexts.
- Within the context of shared-memory, there have been plenty of research and testing going into efficient, scalable & lock-free queue algorithms. This presents an opportunity to port these high-quality algorithms to the distributed context, albeit some inherent differences that need to be taken into consideration between the two contexts.
- In the distributed literature, most of the proposed algorithms completely disregard the existing shared-memory algorithms. This is why we investigate the porting approach & compare them with existing distributed queue algorithms.

## Scope

- Minimum characteristics:

| Dimension           | Desired property        |
| ------------------- | ----------------------- |
| Queue length        | Fixed length            |
| Number of producers | Many                    |
| Number of consumers | One                     |
| Operations          | `queue`, `enqueue`      |
| Concurrency         | Concurrent & Lock-free  |

## Approach

<details>
  <summary>Hybrid MPI+MPI approach?</summary>
  TBU
</details>

<details>
  <summary>How to perform an MPI port in a lock-free manner?</summary>
  TBU
</details>

<details>
  <summary>General porting approach?</summary>
</details>

## Literature review

### Links
- [References](/refs/README.md): Notes for various related papers.

## Evaluation criteria

- Correctness: Correct `queue`/`enqueue` semantics, memory-safe, no undefined-behavior.
- Performance: The less time it takes to serve common workloads on the target platform the better.
- Scalability: The performance gain for `queue` and `enqueue` should scale with the number of threads on the target platform.
- Lock-free-ness: A thread suspended while using the queue should not prevent other threads from making progress using the queue.

## Evaluation strategy

We need to evaluate at least 3 levels:
- Theory verification: Prove that the algorithm possess the desired properties.
- Implementation verifcation: Even though theory is correct, implementation details nuances can affect the desired properties.
  - Static verification: Verify the source code + its dependencies.
  - Dynamic verification: Verify its behavior at runtime.

<details>
  <summary>Caution - Lockfree-ness of dependencies</summary>
  A lock-free algorithm often *assumes* that some synchronization primitive is lock-free. This depends on the target platform and during implementation, the library used. Care must be taken to avoid accidental non-lock-free operation usage.
</details>

### Correctness

### Performance

### Lockfree-ness

### Scalability
