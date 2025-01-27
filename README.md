# Nonblocking distributed MPSC queues using the hybrid programing model combining MPI-3 and C++11

An examination of existing *shared-memory* queue algorithms to:
  - Find a *lock-free*, *concurrent* *multiple-producers single-consumer* queue algorithm.
  - Find a suitable queue algorithm to be ported to distributed context using the hybrid approach MPI+MPI and C++11 for shared-memory synchronization.

## Motivation

- Queue is one of the most basic-but-critical data structures, being the backbone for many applications, such as scheduling, event handling. It's important to ensure that the queue algorithm is performant, scalable and robust.
- There have been plenty of research & testing going into performant & scalable shared-memory queue algorithms. This presents an opportunity to adapt these algorithms into the distributed context. However, in the current distributed computing literature, most algorithms are built from scratch, disregarding the whole shared-memory literature.
- Shared-memory queue algorithms can be ported to distributed context using a programming model which uses the hybrid approach MPI+MPI.
- We intend to investigate the current shared-memory literature to port some shared-memory queue algorithms & compare how well they perform as opposed to current distributed queue algorithms.

## Characteristic

A specialized queue with these (minimum) characteristics:

| Dimension           | Desired property        |
| ------------------- | ----------------------- |
| Queue length        | Fixed length            |
| Number of producers | Many                    |
| Number of consumers | One                     |
| Operations          | `queue`, `enqueue`      |
| Concurrency         | Concurrent & Lock-free  |

## Porting approach

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

### Correctness

### Performance

### Lockfree-ness

### Scalability

## Caution

- A lock-free algorithm often *assumes* that some synchronization primitive is lock-free. This depends on the target platform and during implementation, the library used. Care must be taken to avoid accidental non-lock-free operation usage.

## Links

- [References](/refs/README.md): Notes for various related papers.
