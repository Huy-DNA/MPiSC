= Background <background>

== Multiple-producer, single-consumer (MPSC)

Multiple-producer, single-consumer (MPSC) is a specialized concurrent first-in first-out (FIFO) data structure. A FIFO is a container data structure where items can be inserted into or taken out of, with the constraint that the items that are inserted earlier are taken out of earlier. Hence, it's also known as the queue data structure. The process that performs item insertion into the FIFO is called the producer and the process that performs items deletion (and retrieval) is called the consumer. In concurrent queues, multiple producers and consumers can run in parallel. Concurrent queues have many important applications, namely event handling, scheduling, etc. One class of concurrent FIFOs is MPSC, where one consumer may run in parallel with multiple producers. The reasons we're interested in MPSCs instead of the more general multiple-producer, multiple-consumer data structures (MPMCs) are that (1) high-performance and high-scalability MPSCs are much simpler to design than MPMCs while (2) MPSCs are powerful enough - its consensus number equals the number of producers @dqueue.

== Lock-free algorithms

Many concurrent algorithms are based on locks to create mutual exclusion, in which only some processes that have acquired the locks are able to act, while the others have to wait. While lock-based algorithms are simple to read, write and verify, these algorithms are said to be blocking: One slow process may slow down the other faster processes, for example, if the slow process successfully acquires a lock and then the OS decides to suspends it to schedule another one, this means until the process is awken again, the other processes that contend for the lock cannot continue. Lock-based algorithms introduces many problems such as:
- Deadlock: There's a circular lock-wait dependencies among the processes, effectively prevent any processes from making progress.
- Convoy effect: One long process holding the lock will block other shorter processes contending for the lock.
- Priority inversion: A higher-priority process effectively has very low priority because it has to wait for another low priority process.
Furthermore, if a process that holds the lock dies, this will corrupt the whole program, and this possibility can happen more easily in distributed computing, due to network failures, node falures, etc. This is the reason why the class of lock-free algorithms is studied heavily. Lock-free algorithms provide progress guarantee: Even if some processes are suspended, the remaining processes are ensured to make global progress and complete in bounded time. This property is invaluable in distributed computing, one dead process will not terminate the whole program, providing fault-tolerance. Designing lock-free algorithms requires careful use of atomic instructions, such as Fetch-and-add (FAA), Compare-and-swap (CAS), etc. One well-known technique in achieving lock-freedom is the help mechanism, made popular by @michael-scott.

== Linearizability

Correctness of concurrent algorithms is hard to defined, especially when it comes to the semantics of concurrent data structures like MPSC. One effort to formalize the correctness of concurrent data structures is the definition of *linearizability*. A method call on the FIFO can be visualized as an interval spanning two points in time. The starting point is called the *invocation event* and the ending point is called the *response event*. *Linearizability* informally states that each method call should appear to take effect instantaneously at some moment between its invocation event and response event @art-of-multiprocessor-programming. The moment the method call takes effect is termed the *linearization point*. Specifically, suppose the followings:
  - We have $n$ concurrent method calls $m_1$, $m_2$, ..., $m_n$.
  - Each method call $m_i$ starts with the *invocation event* happening at timestamp $s_i$ and ends with the *response event* happening at timestamp $e_i$. We have $s_i < e_i$ for all $1 lt.eq i lt.eq n$.
  - Each method call $m_i$ has the *linearization point* happening at timestamp $l_i$, so that $s_i lt.eq l_i lt.eq e_i$.
Then, linerizability means that if we have $l_1 < l_2 < ... < l_n$, the effect of these $n$ concurrent method calls $m_1$, $m_2$, ..., $m_n$ must be equivalent to calling $m_1$, $m_2$, ..., $m_n$ *sequentially*, one after the other in that order.

#figure(
  image("/static/images/linearizability.png"),
  caption: [Linerization points of method 1, method 2, method 3, method 4 happens at $t_1 < t_2 < t_3 < t_4$, therefore, their effects will be observed in this order as if we call method 1, method 2, method 3, method 4 sequentially]
)

== ABA problem

== Safe memory reclamation problem

== C++11 concurrency

=== C++11 memory model

=== C++11 atomics

== MPI-3

=== MPI-3 RMA

=== MPI-3 SHM
