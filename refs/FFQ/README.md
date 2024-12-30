# FFQ: A fast single-producer/multiple-consumer concurrent FIFO queue

Paper: https://ieeexplore.ieee.org/document/7967181/references#references

## Context

- The authors were developing a secure application framework that allows execution of programs inside secure enclaves (the one that is supported on the Intel SGX extensions).
- As the OS cannot access the secure enclave's memory, system calls cannot be executed inside the secure enclaves.
- Idea:
  - A pool of OS threads inside the enclave (*enclave OS thread pool*).
  - A pool of OS threads outside the enclave (*non-enclave OS thread pool*).
  - *An enclave OS thread* sends a syscall request to the *enclave OS thread pool*via a FIFO queue.
  - *A non-enclave OS thread* executes the system calls and send back results to the *enclave OS thread pool* via a FIFO queue.
- It's discovered that most of the bottleneck is the FIFO queue, even with the state-of-the-art algorithm (on a 4-core-2-thread Skylake CPU).
- The many-to-many threading model is assumed inside the secure enclave:
  - Multiple *application threads* map to multiple *enclave OS thread*.
  - An *application thread* executing a blocking system call will not block the enclave OS thread it's running on. Rather, the scheduler activation mechanism is utilized to signal the application scheduler to schedule another application thread to be run on that enclave OS thread.

## Requirements

The minimum queue's requirements are:
- SPMC:
  - Each enclave OS thread (producer) keeps a FIFO queue to send to a non-enclave OS thread pool (consumers).
  - Each non-enclave OS thread (producer) keeps a FIFO queue to send to a enclave OS thread pool (consumers).
- Fixed-size: Because each *application thread* mapped to an *enclave OS thread* can only issue one syscall and must wait for it to be finished, the maximum number of syscalls for the queue is known.
- Wait-free `enqueue`
- Lock-free `dequeue`

## The algorithm - single producer

- Goal: Maximize speed and limit synchronization overheads.

- Structure:
  - A *circular buffer* of fixed length.
  - Each item in the queue is monotonically numbered, called its *rank* (insertion number). No two items can have the same rank. An item's index = its rank % `N`.
  - Some *ranks* may be skipped, creating *gaps*.
  - The *head* is the *rank* of the first item in the queue. *Head* is therefore monotonically increasing. *Head* is a shared atomic variable.
  - The *tail* is the *rank* of the last item in the queue. *Tail* is therefore monotonically increasing. *Tail* is not shared, as there is only one producer.
  - Each *cell* in the queue has:
    - The enqueued data.
    - The rank of the item in the cell, if empty, a sentinel is stored.
    - The last skipped rank (gap).
- How a gap arise?
  - The producer wants to write at rank `r1` or at cell index by `r1 mod N`.
  - Some slow consumers have started but have not freed up a cell of rank `r2` where `r2 < r1` and `r2 mod N = r1 mod N`.
  - In this case, the producer will skip the current rank and try the next rank. The cell of the skipped rank has its gap value updated to the skipped rank.

- The algorithm's main idea: No synchronization is needed unless explicitly stated.
  - Init:
    1. Create an array of empty `cell`s. An empty cell has no data, its rank and gap set to sentinel.
    2. Init `tail` and `head` to `0`.
  - Enqueue: Try the following until success:
    1. Grab the `cell` at `tail`.
    2. If the `cell`'s rank is not a sentinel, that means the `cell` is already occupied:
       1. Set the `cell`'s gap to `tail`, which is the current rank.
       2. Increase `tail` by 1, essentially skipping the current rank.
       3. Retry.
    3. Otherwise, the `cell` is not occupied i.e its rank is a sentinel:
       1. Set the `cell`'s data.
       2. Set the `cell`'s rank to `tail`, which is the current rank.
       3. Increase `tail` by 1.
       4. Signal success.
  - Dequeue:
    1. **Atomically** perform fetch-and-add `head` to get the `rank` of the next item.
    2. Get the `cell` corresponding to `rank`.
    3. Try the following until success:
       1. If the `cell`'s rank equals `rank`, that means the cell indeed stores the item with rank `head`:
          1. Extract its data.
          2. Reset its rank to the sentinel.
          3. Signal success.
       2. Otherwise, if the `cell`'s gap >= `rank` and the `cell`'s rank != `rank`, that means this cell was skipped:
          1. **Atomically** perform fetch-and-add `head` and update `rank` to the next rank.
          2. Update `cell` to the next cell.
       3. Otherwise, the consumer waits for the producer to enqueue the value to the current cell.
    4. Return the extracted data.
- Remarks:
  - Possible UB without a proper implementation:
    - There is no synchronization between a producer and a consumer but they read and write non-atomic shared variables, i.e in cases where they are accessing the same cell.
    - Multiple consumers may still try to access the same cell but their intended accessed ranks are different, for example, consumer 1 tries to access cell of rank `C1` while consumer 2 tries to access cell of rank `C1 + N` which maps to the same cell. At most one consumer may modify the cell at a time.

    -> Without memory fences, this algorithm would cause undefined behavior with C++ memory model.
  - The wait-free of `enqueue` is achieved by allowing the producer to skip a cell under the assumption that eventually the producer would find an emtpy cell. If this assumption is violated, the producer would spin for a long time and `enqueue` is no longer wait-free.
  - `dequeue` is not wait-free as if the producer suspends, all the consumers must wait and make no progress, however, consumers do not block each other.
  - The recheck for `cell`'s rank != `rank` in step 3.2 in `dequeue` is to avoid a slow consumer being idle during the time gap between step 3.1 and 3.2 and a producer in the mean time has enqueued an item ranked `rank`, did a full circle, skipped some cells and ended up updating the current `cell`'s gap >= `rank`.
 
## The algorithm - multiple producer

- The algorithm:
  - Enqueue: Try the following until success:
    1. **Atomically** fetch-and-add `tail` to obtain the current `rank`.
    2. Get the `cell` corresponding to the current `rank`.
    3. Loop:
       1. Store the `cell`'s gap into `g`.
       2. If `g >= rank` then this cell's has been taken, break out of the loop.
       3. Store the `cell`'s rank into `r`.
       4. If `r >= 0` then this cell has been used, skip it by performing an **atomic** double-compare-and-swap to:
          - Set the `cell`'s gap to `rank`.
          - Set the `cell`'s rank to `r`.
          If both:
          - `cell`'s gap == `g`.
          - `cell`'s rank == `r`.
          Reloop.
       5. Otherwise, this cell may not have been used, try to reserve it by performin an **atomic** double-compare-and-swap to:
          - Set the `cell`'s gap to `g`.
          - Set the `cell`'s rank to another sentinel with reserve semantic.
          If both:
          - `cell`'s gap == `g`.
          - `cell`'s rank == sentinel.
          If this operation fails, reloop.
          Otherwise:
          1. Set `cell`'s data.
          2. Set `cell`'s rank to `rank`.
          3. Signal success.

## Implementation considerations

- Avoid *false sharing*:
  - 2 mechanisms:
    - *Dedicated cache lines* for each cell.
    - *Address randomization* to ensure that neighboring cells are in different cache lines.
  - How?
    - Use compiler extensions.
    - Pad the data structure to match cache line boundaries.
- Thread affinity: Assigning some threads to specific cores.
  - Pros: Avoid unnecessary cache line invalidation/migration. Exploit instruction-level parallelism.
  - Cons: Overloading a single core.
  - 4 mechanisms:
    - *Same HT*: Producer and all consumers on a *single hardware thread*.
    - *Sibling HT*: Producer on a *single hardware thread* and all consumers on *a second hardware thread* but they are both on the same core.
    - *Other core*: Producer on one core and consumers on another core.
    - *No affinity*: Left to the OS.
- Queue length:
  - Longer queue length:
    - A slow down in a producer affects less adversely to a consumer and vice versa.
    - Less false sharing: Consumers and producer have more chance to access differnt portions of the queue and they tend to share the same cache line less.
  - Shorter queue length: Lower cache hit rate.

## Authors implementation

- Language: C + assembly for atomic operations and memory barriers.
- Memory alignment by compiler directives.
- Thread management: `pthread`.
- Native word size: 64 bit.
- Architectures: Intel x86, IBM POWER8.

Remark: We have to resort to platform-specific & compiler extensions. Can we relying on the portable C++ memory model?

## Evaluation

- Context: The workload is based on the author's secure application framework.
- Micro-benchmarks on the Skylake server. Comparison tests with other queue algorithms on the Skylake, Haswell and P8 server.
  - Skylake. An **Intel** Xeon E3-1270 v5 (4 cores at 3.6 GHz, 8 hardware threads, 8 MB cache) with 64 GB RAM, **Ubuntu** 14.04.4 LTS, **gcc** 6.1.0.
  - Haswell. An **Intel** Xeon E5-2683 v3 (two 14-core CPUs at 2 GHz, 56 hardware threads, 35 MB cache, NUMA) with 112 GB RAM, **Ubuntu** 15.10, **gcc** 5.2.1.
  - P8. An **IBM** POWER8 8284-22A (10 cores at 3.42 GHz, 80 hardware threads, 512 KB L2 and 8 MB L3 cache per core) with 32 GB RAM, **Fedora** 21, **gcc** 4.9.2

### Methodology

- The benchmark:
  - Spawns a number of producer threads and consumer threads.
  - Each producer thread corresponds to a number of consumer of threads (>= 0).
  - The producer has an SPMC queue for sending requests and an SPSC response queue for each consumer.
  - The producer sends some 64-bit integers to the SPMC queue and loops through the SPSC queues to retrieve values.
  - The consumers repeatedly retrieve 64-bit integers from the SPMC queue and sends back to its SPSC queue.
  
  -> Simple benchmark.

- Benchmarks are written in C and compiled using **gcc** with optimization `-O3`.
