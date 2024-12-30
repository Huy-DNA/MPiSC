# MPSC on [platform]

This is an examination of existing concurrent queue algorithms to find a *lock-free*, *concurrent*, *multi-producer single-consumer*, *fixed-length* queue to be run on [platform].

## Characteristic

A specialized queue with these (minimum) characteristics:

| Dimension           | Desired property        |
| ------------------- | ----------------------- |
| Queue length        | Fixed length            |
| Number of producers | Many                    |
| Number of consumers | One                     |
| Operations          | `queue`, `enqueue`      |
| Concurrency         | Concurrent & Lock-free  |

## Evaluation criteria

The queue is meant to be optimized for the platform [platform]. Evaluation criteria:
- Correctness: Correct `queue`/`enqueue` semantics, memory-safe, no undefined-behavior.
- Performance: The less time it takes to serve common workloads on the target platform the better.
- Scalability: The performance gain for `queue` and `enqueue` should scale with the number of threads on the target platform.
- Lock-free-ness: A thread suspended while using the queue should not prevent other threads from making progress using the queue.

## Target environment

### Platform

### Workload

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
