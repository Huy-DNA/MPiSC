= Background <background>

== Irregular applications

Irregular applications are a class of programs particularly interesting in distributed computing. They are characterized by:
- Unpredictable memory access: Before the program is actually run, we cannot know which data it will need to access. We can only know that at run time.
- Data-dependent control flow: The decision of what to do next (such as which data tp accessed next) is highly dependent on the values of the data already accessed. Hence the unpredictable memory access property because we cannot statically analyze the program to know which data it will access. The control flow is inherently engraved in the data, which is not known until runtime.
Irregular applications are interesting because they demand special treatments to achieve high performance. One specific challenge is that this type of applications is hard to model in traditional MPI APIs. The introduction of MPI RMA (remote memory access) in MPI-2 and its improvement in MPI-3 has significantly improved MPI's capability to express irregular applications comfortably.

== Multiple-producer, single-consumer (MPSC)

Multiple-producer, single-consumer (MPSC) is a specialized concurrent first-in first-out (FIFO) data structure. A FIFO is a container data structure where items can be inserted into or taken out of, with the constraint that the items that are inserted earlier are taken out of earlier. Hence, it's also known as the queue data structure. The process that performs item insertion into the FIFO is called the producer and the process that performs items deletion (and retrieval) is called the consumer. In concurrent queues, multiple producers and consumers can run in parallel. Concurrent queues have many important applications, namely event handling, scheduling, etc. One class of concurrent FIFOs is MPSC, where one consumer may run in parallel with multiple producers. The reasons we're interested in MPSCs instead of the more general multiple-producer, multiple-consumer data structures (MPMCs) are that (1) high-performance and high-scalability MPSCs are much simpler to design than MPMCs while (2) MPSCs are powerful enough - its consensus number equals the number of producers @dqueue.

== Progress guarantee

Many concurrent algorithms are based on locks to create mutual exclusion, in which only some processes that have acquired the locks are able to act, while the others have to wait. While lock-based algorithms are simple to read, write and verify, these algorithms are said to be blocking: One slow process may slow down the other faster processes, for example, if the slow process successfully acquires a lock and then the OS decides to suspends it to schedule another one, this means until the process is awken again, the other processes that contend for the lock cannot continue. Lock-based algorithms introduces many problems such as:
- Deadlock: There's a circular lock-wait dependencies among the processes, effectively prevent any processes from making progress.
- Convoy effect: One long process holding the lock will block other shorter processes contending for the lock.
- Priority inversion: A higher-priority process effectively has very low priority because it has to wait for another low priority process.
Furthermore, if a process that holds the lock dies, this will corrupt the whole program, and this possibility can happen more easily in distributed computing, due to network failures, node falures, etc.
Therefore, while lock-based algorithms are easy to write, they do not provide *progress guarantee* because *deadlock* or *livelock* can occur and unnecessarily restrictive regarding its use of mutual exclusion. These algorithms are said to be *blocking*. An algorithm is said to be *non-blocking* if a failure or slow-down in one process cannot cause the failure or slowdown in another process. Lock-free and wait-free algorithms are to especially interesting subclasses of non-blocking algorithms. Unlike lock-based algorithms, they provide *progress guarantee*.

=== Lock-free algorithms

Lock-free algorithms provide the following guarantee: Even if some processes are suspended, the remaining processes are ensured to make global progress and complete in bounded time. This property is invaluable in distributed computing, one dead or suspended process will not block the whole program, providing fault-tolerance. Designing lock-free algorithms requires careful use of atomic instructions, such as Fetch-and-add (FAA), Compare-and-swap (CAS), etc. One well-known technique in achieving lock-freedom is the help mechanism, made popular by @michael-scott.

=== Wait-free algorithms

Wait-freedom is a stronger progress guarantee than lock-freedom. While lock-freedom ensures that at least one of the alive processes will make progress, wait-freedom guarantees that any alive processes will finish in bounded time. Wait-freedom is useful to have because it prevents starvation. Lock-freedom still allows the possibility of one process having to wait for another indefinitely, as long as some still makes progress.

== Correctness - Linearizability

Correctness of concurrent algorithms is hard to defined, especially when it comes to the semantics of concurrent data structures like MPSC. One effort to formalize the correctness of concurrent data structures is the definition of *linearizability*. A method call on the FIFO can be visualized as an interval spanning two points in time. The starting point is called the *invocation event* and the ending point is called the *response event*. *Linearizability* informally states that each method call should appear to take effect instantaneously at some moment between its invocation event and response event @art-of-multiprocessor-programming. The moment the method call takes effect is termed the *linearization point*. Specifically, suppose the followings:
- We have $n$ concurrent method calls $m_1$, $m_2$, ..., $m_n$.
- Each method call $m_i$ starts with the *invocation event* happening at timestamp $s_i$ and ends with the *response event* happening at timestamp $e_i$. We have $s_i < e_i$ for all $1 lt.eq i lt.eq n$.
- Each method call $m_i$ has the *linearization point* happening at timestamp $l_i$, so that $s_i lt.eq l_i lt.eq e_i$.
Then, linerizability means that if we have $l_1 < l_2 < ... < l_n$, the effect of these $n$ concurrent method calls $m_1$, $m_2$, ..., $m_n$ must be equivalent to calling $m_1$, $m_2$, ..., $m_n$ *sequentially*, one after the other in that order.

#figure(
  image("/static/images/linearizability.png"),
  caption: [Linerization points of method 1, method 2, method 3, method 4 happens at $t_1 < t_2 < t_3 < t_4$, therefore, their effects will be observed in this order as if we call method 1, method 2, method 3, method 4 sequentially],
)

== Common issues when designing lock-free algorithms

=== ABA problem

In implementing concurrent lock-free algorithms, hardware atomic instructions are utilized to achieve linearizability. The most popular atomic operation instruction is compare-and-swap (CAS). The reason for its popularity is (1) CAS is a *universal atomic instruction* - it has the *concensus number* of $infinity$ - which means it's the most powerful atomic instruction @herlihy-hierarchy (2) CAS is implemented in most hardware (3) some concurrent lock-free data structures such as MPSC can only be implemented using powerful atomic instruction such as CAS. The semantic of CAS is as follows. Given the instruction `CAS(memory location, old value, new value)`, atomically compares the value at `memory location` to see if it equals `old value`; if so, sets the value at `memory location` to `new value` and returns true; otherwise, leaves the value at `memory location` unchanged and returns false. Concurrent algorithms often utilize CAS as follows:
1. Read the current value `old value = read(memory location)`.
2. Compute `new value` from `old value` by manipulating some resources associated with `old value` and allocating new resources for `new value`.
3. Call `CAS(memory location, old value, new value)`. If that succeeds, the new resources for `new value` remain valid because it was computed using valid resources associated with `old value`, which has not been modified since the last read. Otherwise, free up `new value` because `old value` is no longer there, so its associated resources are not valid.
This scheme is susceptible to the notorious ABA problem:
1. Process 1 reads the current value of `memory location` and reads out `A`.
2. Process 1 manipulates resources associated with `A`, and allocates resources based on these resources.
3. Process 1 suspends.
4. Process 2 reads the current value of `memory location` and reads out `A`.
5. Process 2 `CAS(memory location, A, B)` so that resources associated with `A` are no longer valid.
6. Process 3 `CAS(memory location, B, A)` and allocates new resources associated with `A`.
7. Process 1 continues and `CAS(memory location, A, new value)` relying on the fact that the old resources associated with `A` are still valid while in fact they aren't.

To safe-guard against ABA problem, one must ensure that between the time a process reads out a value from a shared memory location and the time it calls `CAS` on that location, there's no possibility another process has `CAS` the memory location to the same value. Some notable schemes are *monotonic version tag* (used in @michael-scott) and *hazard pointer* (introduced in @hazard-pointer).

=== Safe memory reclamation problem

The problem of safe memory reclamation often arises in concurrent algorithms that dynamically allocate memory. In such algorithms, dynamically-allocated memory must be freed at some point. However, there's a good chance that while a process is freeing memory, other processes contending for the same memory are keeping a reference to that memory. Therefore, deallocated memory can potentially be accessed, which is erroneneous. Solutions ensure that memory is only freed when no other processes are holding references to it. In garbage-collected programming environments, this problem can be conveniently push to the garbage collector. In non-garbage-collected programming environments, however, custom schemes must be utilized. Examples include using a reference counter to count the number of processes holding a reference to some memory and *hazard pointer* @hazard-pointer to announce to other processes that some memory is not to be freed.

== C++11 concurrency

=== Motivation

=== C++11 memory model

=== C++11 atomics

== MPI-3

=== MPI-3 RMA

=== MPI-3 SHM
