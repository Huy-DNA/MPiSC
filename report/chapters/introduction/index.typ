= Introduction <introduction>

The demand for computation power has always been increasing relentlessly. Increasingly complex computation problems arise and accordingly more computation power is required to solve them. Much engineering efforts have been put forth towards obtaining more computation power. A popular topic in this regard is distributed computing: The combined power of clusters of commodity hardware can surpass that of a single powerful machine. To fully take advantage of the potential of distributed computing, specialized algorithms and data structures need to be devised. Noticeably, multi-producer single-consumer (MPSC) is one of those data structures that are utilized heavily in distributed computing, forming the backbone of many applications. Therefore, an MPSC can easily present a performance bottleneck if not designed properly, resulting in loss of computation power. A desirable distributed MPSC should be able to exploit the highly concurrent nature of distributed computing. One favorable characteristic of distributed data structures is non-blocking or more specifically, lock-freedom. Lock-freedom guarantees that if some processes suspend or die, other processes can still complete. This provides both progress guarantee and fault-tolerant, especially in distributed computing where nodes can fail any time. Thus, the rest of this document concerns itself with investigating and devising efficient non-blocking distributed MPSCs. Interestingly, we choose to adapt current MPSC algorithms in the shared-memory literature to port into distributed context.

== Motivation <motivation>

Lock-free MPSC and other FIFO variants, such as multi-producer multi-consumer (MPMC), concurrent single-producer single-consumer (SPSC), are heavily studied in the shared memory literature, dating back from the 1980s-1990s @valois @lamport-leslie @michael-scott and more recently @ltqueue @jiffy. It comes as no surprise that algorithms in this domain are highly developed and optimized for performance and scalability. However, most research about MPSC or FIFO algorithms in general completely disregard the available state-of-the-art algorithms in the shared memory literature. This results in an extremely wasteful use of accumulated research in the shared memory literature, which if adapted and mapped properly to the distributed domain, may produce comparable results to algorithms exclusively devised within the distributed domain. With the new capabilities added to MPI-3 RMA API, porting of lock-free shared-memory algorithms to distributed context is achievable. Therefore, we decide to take a different route to developing new non-blocking MPSC algorithms: Investigate shared-memory MPSC algorithms to port potential ones to distributed context. If this approach is feasible, it instantly opens up a vast shared-memory MSPC algorithms for use in distributed context and proves that there's no need to develop distributed MPSC algorithms from the ground up.

== Objective <objective>

This thesis aims to:
- Investigate state-of-the-art shared-memory MPSCs.
- Select potential MPSC algorithms to be ported to distributed MPSC algorithms using MPI-3 RMA.
- Adapt/Optimize the ported algorithms to fit the constraints of distributed computing.
- Benchmark the ported algorithms.

== Structure <structure>

#pagebreak()
#set heading(offset: 1)
