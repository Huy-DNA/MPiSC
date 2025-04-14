= Introduction <introduction>

#import "@preview/subpar:0.2.2"

== Motivation

The demand for computation power has always been increasing relentlessly. Increasingly complex computation problems arise and accordingly more computation power is required to solve them. Much engineering efforts have been put forth towards obtaining more computation power. A popular topic in this regard is distributed computing: The combined power of clusters of commodity hardware can surpass that of a single powerful machine. To fully take advantage of the potential of distributed computing, specialized distributed algorithms and data structures need to be devised. Hence, there exists a variety of programming environments and frameworks that directly support the execution and development of distribute algorithms and dat structures, one of which is the Message Passing Interface (MPI).

Traditionally, distributed algorithms and data structures use the usual Send/Receive interface to communicate and synchronize between cluster nodes. Meanwhile, in the shared memory literature, atomic instructions are the preferred methods for communication and synchronization. This is due to the historical differences between the architectural support and programming models utilized in these two areas. For a class of problems known as regular applications, the use of the traditional Send/Receive interface suffices. However, this interface poses a challenge for irregular applications (@irregular-applications[]). However, since the introduction of specialized networking hardware such as RDMA and the improved support of the remote memory access (RMA) programming model in MPI-3, this challenge has been alleviated: irregular applications can now be expressed more conveniently with an API that's similar to atomic operations in shared memory programming. This also implies that shared-memory algorithms and data structures can also be ported to distributed environments in a more straightforward manner. Since the design and development of shared-memory algorithms and data structures have been extensively studied, this has opened up a lot new research (@bclx) on reusing the principles of the shared memory literature to distributed computing.

Concurrent multi-producer single-consumer (MPSC) queue is one of those data structures that have seen many applications in shared-memory environments and is embedded in many programming patterns, such as the actor model and the fan-out/fan-in pattern, as shown in @mpsc-patterns.

#subpar.grid(
  figure(
    image("../../static/images/actor_model.png"),
    caption: [
      Actor model
    ],
  ),
  <actor-model>,
  figure(
    image("../../static/images/fan-out_fan-in.png"),
    caption: [
      Fan-out/Fan-in pattern
    ],
  ),
  <fan-out-fan-in-pattern>,
  columns: (1fr, 1fr),
  caption: [Some programming patterns involving the MPSC queue data structure],
  label: <mpsc-patterns>,
)

In the actor model, each process or compute node is represented as an actor. Each actor has a mailbox, which exhibits MPSC queue property: Other actors can send messages to the mailbox and the owner actor extracts messages and performs computation based on these messages. The fan-out/fan-in pattern involves splitting a task into multiple subtasks to workers, then the workers queue back the result to the master, who dequeues out the results to perform further processing, such as aggregation. These patterns can be potentially useful if they can be expressed efficiently in distributed environments. However, we have found dicussions of distributed MPSC queue algorithms in the current literature to be very scarce and scattered and as far as we know, none has focused on designing an efficient distributed MPSC queue. The closest we found is the Berkeley Container Library (BCL) @bcl that provides many distributed data structures including a multi-producer single-consumer (MPMC) queue and multi-producer/multi-consumer (MP/MC) queue. This presents an inhibition to programmers that want to either directly use the distributed MPSC queues or express programming patterns that inherently express MPSC queue behaviors, they either have to work around the requirement or remodel their problems in another way. If a distributed MPSC queue is also provided as part of a library, this can in turn encourage many distributed applications and programming patterns that utilize the MPSC queues.

A desirable distributed MPSC queue algorithms should possess two favorable characteristics (1) scalability, the ability of an algorithm to utilize the highly concurrent nature of distributed clusters (2) fault-tolerance, the ability of an algorithm to continue running despite the failure of some compute nodes. Scalability is important for any concurrent algorithms, as one would never want to add more compute nodes just for performance to drop. Fault-tolerance, on the other hand, is especially more important in distributed computing, as failures can happen more frequently, such as network failures, node failures, etc. Fault-tolerance is concerned with a class of properties arisen in concurrent algorithms known as progress guarantee (@progress-guarantee[]). Specifically, lock-freedom is one such property that allows an algorithm to keep running even when there's some suspended processes.

Lock-free MPSC queues and other FIFO variants, such as multi-producer multi-consumer (MPMC), concurrent single-producer single-consumer (SPSC), have been heavily studied in the shared memory literature, dating back from the 1980s-1990s @valois @lamport-leslie @michael-scott and more recently @ltqueue @jiffy. It comes as no surprise that lock-free algorithms in this domain are highly developed and optimized for performance and scalability. However, most research about distributed algorithms and data structures in general completely disregard the available state-of-the-art algorithms in the shared memory literature. Because shared-memory algorithms can now be straightforwardly ported to distributed context using this programming model, this presents an opportunity to make use of the highly accumulated research in the shared memory literature, which if adapted and mapped properly to the distributed context, may produce comparable results to algorithms exclusively devised within the distributed computing domain. Therefore, we decide to take this novel route to developing new non-blocking MPSC queue algorithms: Utilizing shared-memory programming techniques, adapting potential lock-free shared-memory MSPCs to design fault-tolerant and performant distribute MPSC queue algorithms. If this approach proves to be effective, a huge intellectual reuse of the shared-memory literature into the distributed domain is possible. Consequently, there may be no need to develop distributed MPSC queue algorithms from the ground up.

== Research question

We revolve our research effort around this main question:

#quote()[How to utilize shared-memory programming techniques to model and design distributed MPSC queue algorithms in a fault-tolerant and performant manner?]

We further decompose this question into smaller subquestions:
+ Which factor contributes to the fault-tolerance and performance of a distributed MPSC queue algorithms?
+ Which shared-memory programming technique is relevant in modeling and designing distributed MPSC queue algorithms in a fault-tolerant and performant manner?
+ Which shared-memory programming technique needs to be modified to more effectively model and design distributed MPSC queue algorithms in a fault-tolerant and performant manner?

== Thesis overview

== Objective <objective>

This thesis aims to:
- Investigate state-of-the-art shared-memory MPSC queues.
- Select and appropriately modify potential MPSC queue algorithms so they can be implemented in popular distributed programming environments.
- Port MPSC queue algorithms using MPI-3 RMA.
- Evaluate various theoretical aspects of ported MPSC queue algorithms: Correctness, progress guarantee, time complexity analysis.
- Benchmark the ported MPSC queue algorithms and compare them with current distributed MPSC queues in the literature.
- Discover distributed-environment-specific optimization opportunities for ported MPSC queue algorithms.

== Scope <scope>

- For related works on shared-memory MPSC queues, we only focus on linearizable MPSC queues that support at least lock-free `enqueue` and `dequeue` operations.
- Any implementation details, benchmarking and optimizations assume MPI-3 settings.
- For optimizations, we focus on performance-related metrics, e.g. time-complexity (theoretically), throughput (empirically).

== Structure <structure>

The rest of this report is structured as follows:

@background[] discusses the theoretical foundation this thesis is based on and the technical terminology that's heavily utilized in this domain. As mentioned, this thesis investigates state-of-the-art shared-memory MPSC queues. Therefore, we discuss the theory related to the design of concurrent algorithms such as lock-freedom and linearizability, the practical challenges such as the ABA problem and safe memory reclamation problem. We then explore the utilities offered by C++11 to implement concurrent algorithms and MPI-3 to port shared memory algorithms.

@related-works[] surveys the shared-memory literature for state-of-the-art queue algorithms, specifically MPSC queues. We specifically focus on algorithms that have the potential to be ported efficiently to distributed context, such as NUMA-aware or can be made to be NUMA-aware. We then conclude with a comparison of the most potential shared-memory queue algorithms.

@distributed-queues[] documents distributed-versions of potential shared-memory MPSC queue algorithms surveys in @related-works[]. It specifically presents our adaptation efforts of existing algorithms in the shared-memory literature to make their distributed implementations feasible.

@theoretical-aspects[] discusses various interesting theoretical aspects of our distributed MPSC queue algorithms in @distributed-queues[], specifically correctness (linearizability), progress guarantee (lock-freedom and wait-freedom), performance model. Our analysis of performance model helps back our empirical findings in @result[], together, they work hand-in-hand to help us discover optimization opportunities.

@result[] introduces our benchmarking setup, including metrics, environments, benchmark/microbenchmark suites and conducting methods. We aim to demonstrate some preliminary results on how well ported shared-memory MPSC queues can compare to existing distributed MPSC queues. Finally, we discuss important factors that affect the runtime properties distributed MPSC queue algorithm, which have partly been explained by our theoretical analysis in @theoretical-aspects[].

@conclusion[] concludes what we have accomplished in this thesis and considers future possible improvements to our research.
