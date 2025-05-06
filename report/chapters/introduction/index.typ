= Introduction <introduction>

#import "@preview/subpar:0.2.2"

This chapter details the motivation for our research topic: "Studying and developing nonblocking distributed MPSC queues", based on which we set out the objectives and scope of this study. To summarize, we then come to the formulation of our research question and give a high-level overview of the thesis. We end this chapter with a brief description of the structure of the rest of this document.

== Motivation

The demand for computation power has been increasing relentlessly. Increasingly complex computation problems arise and accordingly more computation power is required to solve them. Much engineering efforts have been put forth towards obtaining more computation power. A popular topic in this regard is distributed computing: The combined power of clusters of commodity hardware can surpass that of a single powerful machine. To fully take advantage of the potential of distributed computing, specialized distributed algorithms and data structures need to be devised. Hence, there exists a variety of programming environments and frameworks that directly support the execution and development of distribute algorithms and data structures, one of which is the Message Passing Interface (MPI).

Traditionally, distributed algorithms and data structures use the usual Send/Receive message passing interface to communicate and synchronize between cluster nodes. Meanwhile, in the shared memory literature, atomic instructions are the preferred methods for communication and synchronization. This is due to the historical differences between the architectural support and programming models utilized in these two areas. For a class of problems known as regular applications, the use of the traditional Send/Receive interface suffices. However, this interface poses a challenge for irregular applications (@irregular-applications). Fortunately, since the introduction of specialized networking hardware such as RDMA and the improved support of the remote memory access (RMA) programming model in MPI-3, this challenge has been alleviated: irregular applications can now be expressed more conveniently with an API that's similar to atomic operations in shared memory programming. This also implies that shared-memory algorithms and data structures can also be ported to distributed environments in a more straightforward manner. Since the design and development of shared-memory algorithms and data structures have been extensively studied, this has opened up a lot new research such as @bclx on applying the principles of the shared memory literature to distributed computing.

Concurrent multi-producer single-consumer (MPSC) queue is one of those data structures that have seen many applications in shared-memory environments and plays the central role in many programming patterns, such as the actor model and the fan-out/fan-in pattern, as shown in @mpsc-patterns.

#subpar.grid(
  figure(
    image("../../static/images/actor_model.png"),
    caption: [
      Actor model.
    ],
  ),
  <actor-model>,
  figure(
    image("../../static/images/fan-out_fan-in.png"),
    caption: [
      Fan-out/Fan-in pattern.
    ],
  ),
  <fan-out-fan-in-pattern>,
  columns: (1fr, 1fr),
  caption: [Some programming patterns involving the MPSC queue data structure.],
  label: <mpsc-patterns>,
)

In the actor model, each process or compute node is represented as an actor. Each actor has a mailbox, which exhibits MPSC queue property: Other actors can send messages to the mailbox and the owner actor extracts messages and performs computation based on these messages. The fan-out/fan-in pattern involves splitting a task into multiple subtasks to workers, then the workers queue back the result to the master, who dequeues out the results to perform further processing, such as aggregation. These patterns can be potentially useful if they can be expressed efficiently in distributed environments. However, we have found dicussions of distributed MPSC queue algorithms in the current literature to be very scarce and scattered and as far as we know, none has focused on designing an efficient distributed MPSC queue. The closest we found is the Berkeley Container Library (BCL) @bcl that provides many distributed data structures including a multi-producer multi-consumer (MPMC) queue and multi-producer/multi-consumer (MP/MC) queue and @amqueue which discusses the design of a distributed multi-producer single-consumer (MPSC) queue to support a pattern of message exchange. This presents an inhibition to programmers that want to either directly use the distributed MPSC queues or express programming patterns that inherently express MPSC queue behaviors, they either have to work around the requirement or remodel their problems in another way. If a distributed MPSC queue is also provided as part of a library, this can in turn encourage many distributed applications and programming patterns that utilize the MPSC queues.

A desirable distributed MPSC queue algorithms should possess two favorable characteristics (1) scalability, the ability of an algorithm to utilize the highly concurrent nature of distributed clusters (2) fault-tolerance, the ability of an algorithm to continue running despite the failure of some compute nodes. Scalability is important for any concurrent algorithms, as one would never want to add more compute nodes just for performance to drop. Fault-tolerance, on the other hand, is especially more important in distributed computing, as failures can happen more frequently, such as network failures, node failures, etc. Fault-tolerance is concerned with a class of properties arisen in concurrent algorithms known as progress guarantee (@progress-guarantee). Non-blocking is a class of progress guarantee that ensures that the failure of one process does not cause the failure of the others.

Non-blocking MPSC queues and other FIFO variants, such as multi-producer multi-consumer (MPMC) queue, single-producer single-consumer (SPSC) queue, have been heavily studied in the shared memory literature, dating back from the 1980s-1990s @valois @lamport-leslie @michael-scott and more recently @ltqueue @jiffy. It comes as no surprise that non-blocking algorithms in this domain are highly developed and optimized for performance and scalability. However, most research about distributed algorithms and data structures in general completely disregard the available state-of-the-art algorithms in the shared memory literature. Because shared-memory algorithms can now be straightforwardly ported to distributed context using this programming model, this presents an opportunity to make use of the highly accumulated research in the shared memory literature, which if adapted and mapped properly to the distributed context, may produce comparable results to algorithms exclusively devised within the distributed computing domain. Therefore, we decide to take this novel route to developing new non-blocking MPSC queue algorithms: Utilizing shared-memory programming techniques, adapting potential lock-free shared-memory MSPCs to design fault-tolerant and performant distributed MPSC queue algorithms. If this approach proves to be effective, a huge intellectual reuse of the shared-memory literature into the distributed domain is possible. Consequently, there may be no need to develop distributed MPSC queue algorithms from the ground up.

== Objective <objective>

Based on what we have listed out in the previous section, we aim to:
- Investigate the principles underpinning the design of fault-tolerant and performant shared-memory algorithms.
- Investigate state-of-the-art shared-memory MPSC queue algorithms as case studies to support our design of distributed MPSC queue algorithms.
- Investigate existing distributed FIFO algorithms that can be adapted for MPSC use cases to serve as a comparison baseline.
- Model and design distributed MPSC queue algorithms using techniques from the shared-memory literature.
- Utilize the shared-memory programming model to evaluate various theoretical aspects of distributed MPSC queue algorithms: correctness and progress guarantee.
- Model the theoretical performance of distributed MPSC queue algorithms that are designed using techniques from the shared-memory literature.
- Collect empirical results on distributed MPSC queue algorithms and discuss important factors that affect these results.

== Scope <scope>

The following narrows down what we're going to investigate in the shared-memory literature and which theoretical and empirical aspects we're interested in our distributed algorithms:
- Regarding the investigation of the design principles in the shared-memory literature, we focus on fault-tolerant and performant concurrent algorithm design using atomic operations and common problems that often arise in this area, namely, ABA problem and safe memory reclamation problem.
- Regarding the investigation of shared-memory MPSC queues currently in the literature, we focus on linearizable MPSC queues that support at least lock-free `enqueue` and `dequeue` operations.
- Regarding correctness, we're concerned ourselves with the linearizability correctness condition.
- Regarding fault-tolerance, we're concerned ourselves with the concept of progress guarantee, that is, the ability of the system to continue to make forward process despite the failure of one or more components of the system.
- Regarding algorithm prototyping, benchmarking and optimizations, we assume an MPI-3 setting.
- Regarding empirical results, we focus on performance-related metrics, e.g. throughput and latency.

== Research question

Any research effort in this thesis revolves around this research question:

#quote()[How to utilize shared-memory programming principles to model and design distributed MPSC queue algorithms in a correct, fault-tolerant and performant manner?]

We further decompose this question into smaller subquestions:
+ Which factor contributes to the fault-tolerance and performance of a distributed MPSC queue algorithms?
+ Which shared-memory programming principle is relevant in modeling and designing distributed MPSC queue algorithms in a fault-tolerant and performant manner?
+ Which shared-memory programming principle needs to be modified to more effectively model and design distributed MPSC queue algorithms in a fault-tolerant and performant manner?

== Thesis overview

An overview of this thesis is given in @thesis-overview.

This thesis explores the shared-memory programming model to design fault-tolerant and performant concurrent algorithms using atomic operations. Traditionally, in this aspect, two notorious problems often arise: ABA problem and safe memory reclamation. We investigate the traditional techniques used in the shared-memory literature to resolve these problems and appropriately adapt them to solve similar issues when designing fault-tolerant and performant distributed MPSC queues.

This thesis contributes two new distributed wait-free distributed MPSC queue algorithms. Theoretically, we're concerned ourselves with their correctness (linearizability), progress guarantee (lock-freedom and wait-freedom) which has an implication on their fault-tolerance and their theoretical performance, which is approximated by their number of remote operations and local operations.

This thesis concludes with an empirical analysis of our novel algorithms to see if their actual behavior matches our theoretical performance model, interpret these results and discuss its implication.

#place(
  center + top,
  float: true,
  scope: "parent",
  [#figure(
      image("/static/images/thesis-overview.png"),
      caption: [An overview of this thesis.],
    ) <thesis-overview>
  ],
)

== Structure <structure>

The rest of this report is structured as follows:

@background[] discusses the theoretical foundation this thesis is based on. As mentioned, this thesis investigates the principles of shared-memory programming and the existing state-of-the-art shared-memory MPSC queues. We then explore the utilities offered by MPI-3 to implement distributed algorithms modeled by shared-memory programming techniques.

@related-works[] surveys the shared-memory literature for state-of-the-art queue algorithms, specifically MPSC queues. We specifically focus on non-blocking shared-memory algorithms that have the potential to be adapted efficiently for distributed environment. This chapter additionally surveys existing distributed FIFO algorithms to serve as a comparison baseline for our novel distributed MPSC queue algorithms.

@distributed-queues[] introduces our novel distributed MPSC queue algorithms, designed using shared-memory programming techniques and inpsired by the selected shared-memory MPSC queue algorithms surveyed in @related-works[]. It specifically presents our adaptation efforts of existing algorithms in the shared-memory literature to make their distributed implementations feasible and efficient. This chapter also introduces existing FIFO queues in the literature adapted for MPSC use cases. We aim to keep the adaptation as least intrusive as possible for fairness.

@theoretical-aspects[] discusses various interesting theoretical aspects of our distributed MPSC queue algorithms in @distributed-queues[], specifically correctness (linearizability), progress guarantee (lock-freedom and wait-freedom), performance model. Our analysis of the algorithm's performance model helps back our empirical findings in @result[].

@result[] details our benchmarking metrics and elaborates our benchmarking setup. We aim to demonstrate some preliminary results on how well our novel MPSC queue algorithms, additionally compared to existing distributed FIFO queues. Finally, we discuss important factors that affect the runtime properties distributed MPSC queue algorithm, which have partly been explained by our theoretical analysis in @theoretical-aspects[].

@conclusion[] concludes what we have accomplished in this thesis and considers future possible improvements to our research.
