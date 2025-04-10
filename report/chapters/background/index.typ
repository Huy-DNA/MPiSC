#import "@preview/lovelace:0.3.0": *

= Background <background>

== Irregular applications

Irregular applications are a class of programs particularly interesting in distributed computing. They are characterized by:
- Unpredictable memory access: Before the program is actually run, we cannot know which data it will need to access. We can only know that at run time.
- Data-dependent control flow: The decision of what to do next (such as which data tp accessed next) is highly dependent on the values of the data already accessed. Hence the unpredictable memory access property because we cannot statically analyze the program to know which data it will access. The control flow is inherently engraved in the data, which is not known until runtime.
Irregular applications are interesting because they demand special treatments to achieve high performance. One specific challenge is that this type of applications is hard to model in traditional MPI APIs. The introduction of MPI RMA (remote memory access) in MPI-2 and its improvement in MPI-3 has significantly improved MPI's capability to express irregular applications comfortably.

== Multiple-producer, single-consumer (MPSC)

Multiple-producer, single-consumer (MPSC) is a specialized concurrent first-in first-out (FIFO) data structure. A FIFO is a container data structure where items can be inserted into or taken out of, with the constraint that the items that are inserted earlier are taken out of earlier. Hence, it's also known as the queue data structure. The process that performs item insertion into the FIFO is called the producer and the process that performs items deletion (and retrieval) is called the consumer. In concurrent queues, multiple producers and consumers can run in parallel. Concurrent queues have many important applications, namely event handling, scheduling, etc. One class of concurrent FIFOs is MPSC, where one consumer may run in parallel with multiple producers. The reasons we're interested in MPSCs instead of the more general multiple-producer, multiple-consumer data structures (MPMCs) are that (1) high-performance and high-scalability MPSCs are much simpler to design than MPMCs while (2) MPSCs are powerful enough to solve certain problems. Thus, MPSCs can see many use cases like MPMCs while being easily scalable and performant.

== Progress guarantee

Many concurrent algorithms are based on locks to create mutual exclusion, in which only some processes that have acquired the locks are able to act, while the others have to wait. While lock-based algorithms are simple to read, write and verify, these algorithms are said to be blocking: One slow process may slow down the other faster processes, for example, if the slow process successfully acquires a lock and then the operating system (OS) decides to suspends it to schedule another one, this means until the process is awaken, the other processes that contend for the lock cannot continue. Lock-based algorithms introduces many problems such as:
- Deadlock: There's a circular lock-wait dependencies among the processes, effectively prevent any processes from making progress.
- Convoy effect: One long process holding the lock will block other shorter processes contending for the lock.
- Priority inversion: A higher-priority process effectively has very low priority because it has to wait for another low priority process.
Furthermore, if a process that holds the lock dies, this will halt the whole program. This consideration holds even more weight in distributed computing because of a lot more failure modes, such as network failures, node falures, etc.

Therefore, while lock-based algorithms are easy to write, they do not provide *progress guarantee* because *deadlock* or *livelock* can occur and its use of mutual exclusion is unnecessarily restrictive. These algorithms are said to be *blocking*. An algorithm is said to be *non-blocking* if a failure or slow-down in one process cannot cause the failure or slow-down in another process. Lock-free and wait-free algorithms are to especially interesting subclasses of non-blocking algorithms. Unlike lock-based algorithms, they provide *progress guarantee*.

=== Lock-free algorithms

Lock-free algorithms provide the following guarantee: Even if some processes are suspended, the remaining processes are ensured to make global progress and complete in bounded time. This property is invaluable in distributed computing, one dead or suspended process will not block the whole program, providing fault-tolerance. Designing lock-free algorithms requires careful use of atomic instructions, such as Fetch-and-add (FAA), Compare-and-swap (CAS), etc.

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

In implementing concurrent lock-free algorithms, hardware atomic instructions are utilized to achieve linearizability. The most popular atomic operation instruction is compare-and-swap (CAS). The reason for its popularity is (1) CAS is a *universal atomic instruction* - it has the *concensus number* of $infinity$ - which means it's the most powerful atomic instruction @herlihy-hierarchy (2) CAS is implemented in most hardware (3) some concurrent lock-free data structures such as MPSCs are more easily expressed using a powerful atomic instruction such as CAS. The semantic of CAS is as follows. Given the instruction `CAS(memory location, old value, new value)`, atomically compares the value at `memory location` to see if it equals `old value`; if so, sets the value at `memory location` to `new value` and returns true; otherwise, leaves the value at `memory location` unchanged and returns false. Concurrent algorithms often utilize CAS as follows:
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

To safe-guard against ABA problem, one must ensure that between the time a process reads out a value from a shared memory location and the time it calls `CAS` on that location, there's no possibility another process has `CAS` the memory location to the same value. Some notable schemes are *monotonic version tag* (@michael-scott) and *hazard pointer* (@hazard-pointer).

=== Safe memory reclamation problem

The problem of safe memory reclamation often arises in concurrent algorithms that dynamically allocate memory. In such algorithms, dynamically-allocated memory must be freed at some point. However, there's a good chance that while a process is freeing memory, other processes contending for the same memory are keeping a reference to that memory. Therefore, deallocated memory can potentially be accessed, which is erroneneous. Solutions ensure that memory is only freed when no other processes are holding references to it. In garbage-collected programming environments, this problem can be conveniently push to the garbage collector. In non-garbage-collected programming environments, however, custom schemes must be utilized. Examples include using a reference counter to count the number of processes holding a reference to some memory and *hazard pointer* @hazard-pointer to announce to other processes that some memory is not to be freed.

// == C++11 concurrency
//
// === Motivation
//
// C++11 came with a lot of improvements. One such improvement is the native support of multithreading inside the C++ standard library (STL). The main motivation was portability and ergonomics along with two design goals: high-level OOP facilities for working with multithreading in general while still exposing enough low-level details so that performance tuning is possible when one wants to drop down to this level. @cpp-conc
//
// Before C++11, to write concurrent code, programmers had to resort to compiler-specific extensions @cpp-conc. This worked but was not portable as the additional semantics of concurrency introduced by compiler extensions was not formalized in the C++ standard. Therefore, C++11 had come to define a multithreading-aware memory model, which is used to dictate correct concurrent C++11 programs.
//
// === C++11 memory model
//
// The C++11 memory model plays the foundational role in enabling native multithreading support. The C++11 memory model is not a syntatical feature or a library feature, rather it's a model to reason about the semantics of concurrent C++11 programs. In other words, the C++11 multithreading-aware memory model enables the static analysis of concurrent C++11 programs. This, in essence, is beneficial to two parties: the compiler and the programmer.
//
// From the compiler's point of view, it needs to translate the source code into correct machine code. Many modern CPUs are known to utilize out-of-order execution, or instruction reordering to gain better pipeline throughput. This reordering is transparent with respect to a single thread - it still observes the effect of the instructions in the program order. However, this reordering is not transparent in concurrent programs, in which case, synchronizing instructions are necessary, so the compiler has to keep this in mind. With the possibility of concurrency, it needs to conservatively apply optimizations as certain optimizations only work in sequential programs. However, optimization is important to achieve performance, if the compiler just disables the any optimizations altogether in the face of concurrency, the performance gained by using concurrency would be adversely affected. Here, the C++11 memory model comes into play. It allows the compiler to reason which optimization is valid and which is not in the presence of concurrency. Additionally, the compiler can reason about where to place synchronizing instructions to ensure the correctness of concurrent operations. Therefore, the C++11 memory allows the compiler to generate correct and performant machine code.
//
// Similarly, from the programmer's point of view, one can verify that their concurrent program's behavior is well-defined and reason whether their programs unnecessarily disable any optimizations. This, helps the programmer to write correct and performant C++11 concurrent programs.
//
// The C++11 memory consists of two aspects: the *structural* aspects and the *concurrency* aspects @cpp-conc.
//
// ==== Structural aspects
//
// The structural aspects deal with how variables are laid out in memory.
//
// An *object* in C++ is defined as "a region of storage". Concurrent accesses can happen to any "region of storage". These regions of storage can vary in size. One can say that there are always concurrent accesses to RAM. However, do these concurrent accesses always cause race conditions? Intuitively, no. To properly define which concurrent accesses can actually cause race conditions, the C++11 memory model defines the concept of *memory location*. That is, the C++11 memory model views an object as one or more *memory locations*. Only concurrent accesses to the same memory location can possibly cause race conditions. Conflicting concurrent accesses to the same memory location (read/write or write-write) always cause race conditions.
//
// The rule of what comprise a memory location is as follows @cpp-conc:
// - Any object or sub-object (class instance's field) of a scalar type is a memory location.
// - Any sequence of adjacent bit fields is also a memory location.
//
// An example: In the below struct, `a` is a memory location, `b` and `c` is another and `d` is the last.
//
// #figure(
//   kind: "algorithm",
//   supplement: "Listing",
//   caption: "Example memory locations for a user-defined struct",
//   [
//     ```cpp
//     struct S {
//       int a;
//       int b: 8;
//       int c: 8;
//            : 0;
//       int d: 12;
//     }
//     ```
//   ],
// )
//
// ==== Concurrency aspects
//
// Generally speaking, concurrent accesses to different memory locations are fine while concurrent accesses to the same memory location cause race conditions. However, race conditions do not necessarily cause undefined behavior. To avoid undefined behavior with concurrent accesses to the same memory location, one must use atomic operations. The semantics of C++11 atomics will be discussed in the next section.
//
// === C++11 atomics
//
// An atomic operation is an indivisible operation, that is, it either hasn't started executing or has finished executing @cpp-conc.
//
// Atomic operations can only be performed on atomic types: C++11 introduces the `std::atomic<T>` template type, wrapping around a non-atomic type to allow atomic operations on objects of that type. Additionally, C++11 also introduces the `std::atomic_flag` type that acts like an atomic flag. One special property of `std::atomic_flag` is that any operations on it is guaranteed to be lock-free, while the others depend on the platform and size.
//
// By C++17, `std::atomic_flag` only supports two operations:
//
// #figure(
//   kind: "table",
//   supplement: "Table",
//   caption: [Supported atomic operations on `std::atomic_flag` (C++17)],
//   table(
//     columns: (1fr, auto),
//     table.header([*Operation*], [*Usage*]),
//     [`clear`], [Atomically sets the flag to `false`],
//     [`test_and_set`],
//     [Atomically sets the flag to `true` and returns its previous value],
//   ),
// )
//
// Because of its simplicity, `std::atomic_flag` operations are guaranteed to be lock-free.
//
// Some available operations on other atomic types are summarized in the following table @cpp-conc:
//
// #figure(
//   kind: "table",
//   supplement: "Table",
//   caption: [Available atomic operations on atomic types (C++17)],
//   table(
//     columns: (1fr, 1fr, 1fr, 1fr, 1fr),
//     table.header(
//       [*Operation*],
//       [*`atomic<bool>`*],
//       [*`atomic<T*>`*],
//       [*`atomic`` <integral-type>`*],
//       [*`atomic` `<other-type>`*],
//     ),
//
//     [`load`], [Y], [Y], [Y], [Y],
//     [`store`], [Y], [Y], [Y], [Y],
//     [`exchange`], [Y], [Y], [Y], [Y],
//     [`compare_` `exchange_` `weak`, `compare_` `exchange_` `strong`],
//     [Y],
//     [Y],
//     [Y],
//     [Y],
//
//     [`fetch_add`, `+=`], [], [Y], [Y], [],
//     [`fetch_sub`, `-=`], [], [Y], [Y], [],
//     [`fetch_or`, `|=`], [], [], [Y], [],
//     [`fetch_and`, `&=`], [], [], [Y], [],
//     [`fetch_xor`, `^=`], [], [], [Y], [],
//     [`++`, `--`], [], [Y], [Y], [],
//   ),
// )
//
// Each atomic operation can generally accept an argument of type `std::memory_order`, which is used to specify how memory accesses are to be ordered around an atomic operation.
//
// Any atomic operations beside `load` and `store` is called read-modified-write (RMW) operations.
//
// The following is the table of possible `std::memory_order` values:
//
// #figure(
//   kind: "table",
//   supplement: "Table",
//   caption: [Available `std::memory_order` values (C++17). On the `Load`, `Store` and `RMW` columns, `Y` means that this memory order can be specified on `load`, `store` and RMW operations, `-` means that we intentionally ignore this entry.],
//   table(
//     columns: (2fr, 4fr, 1fr, 1fr, 1fr),
//     table.header([*Name*], [*Usage*], [Load], [Store], [RMW]),
//     [`memory_order` `_relaxed`],
//     [No synchronization imposed on other reads or writes],
//     [Y],
//     [Y],
//     [Y],
//
//     [`memory_order` `_acquire`],
//     [No reads or writes after this operation in the current thread can be reordered before this operation],
//     [Y],
//     [],
//     [Y],
//
//     [`memory_order` `_release`],
//     [No reads or writes before this operation in the current thread can be reordered after this operation],
//     [],
//     [Y],
//     [Y],
//
//     [`memory_order` `_acq_rel`],
//     [No reads or writes before this operation in the current thread can be reordered after this operation. No reads or writes after this operation can be reordered before this operation],
//     [],
//     [],
//     [Y],
//
//     [`memory_order` `_seq_cst`],
//     [A global total order exists on all modifications of atomic variables],
//     [Y],
//     [Y],
//     [Y],
//
//     [`memory_order` `_consume`], [Not recommended], [-], [-], [-],
//   ),
// )
//
// In conclusion, atomic operations avoid undefined behavior on concurrent accesses to the same memory location while memory orders help us enforce ordering of operations accross threads, which can be used to reason about the program.

== MPI-3

MPI stands for message passing interface, which is a *message-passing library interface specification*. Design goals of MPI includes high availability across platforms, efficient communication, thread-safety, reliable and convenient communication interface while still allowing hardware-specific accelerated mechanisms to be exploited @mpi-3.1.

=== MPI-3 RMA

RMA in MPI RMA stands for remote memory access. As introduced in the first section of @background, RMA APIs is introduced in MPI-2 and its capabilities are further extended in MPI-3 to conveniently express irregular applications. In general, RMA is intended to support applications with dynamically changing data access patterns where the data distribution is fixed or slowly changing @mpi-3.1. In such applications, one process, based on the data it needs, knowing the data distribution, can compute the nodes where the data is stored. However, because data acess pattern is not known, each process cannot know whether any other processes will access its data.

Using the traditional `Send`/`Receive` interface, both sides need to issue matching operations by distributing appropriate transfer parameters. This is not suitable, as previously explain, only the side that needs to access the data knows all the transfer parameters while the side that stores the data cannot anticipate this.

=== MPI-RMA communication operations

RMA only requires one side to specify all the transfer parameters and thus only that side to participate in data communication.

To utilize MPI RMA, each process needs to open a memory window to expose a segment of its memory to RMA communication operations such as remote writes (`MPI_PUT`), remote reads (`MPI_GET`) or remote accumulates (`MPI_ACCUMULATE`, `MPI_GET_ACCUMULATE`, `MPI_FETCH_AND_OP`, `MPI_COMPARE_AND_SWAP`) @mpi-3.1. These remote communication operations only requires one side to specify.

=== MPI-RMA synchronization

Besides communication of data from the sender to the receiver, one also needs to synchronize the sender with the receiver. That is, there must be a mechanism to ensure the completion of RMA communication calls or that any remote operations have taken effect. For this purpose, MPI RMA provides *active target synchronization* and *passive target synchronization*. In this document, we're particularly interested in *passive target synchronization* as this mode of synchronization does not require the target process of an RMA operation to explicitly issue a matching synchronization call with the origin process, easing the expression of irregular applications @dinan.

In *passive target synchronization*, any RMA communication calls must be within a pair of `MPI_Win_lock`/`MPI_Win_unlock` or `MPI_Win_lock_all`/`MPI_Win_unlock_all`. After the unlock call, those RMA communication calls are guaranteed to have taken effect. One can also force the completion of those RMA communication calls without the need for the call to unlock using flush calls such as `MPI_Win_flush` or `MPI_Win_flush_local`.

#figure(
  image("/static/images/passive_target_synchronization.png"),
  caption: [An illustration of passive target communication. Dashed arrows represent synchronization (source: @mpi-3.1)],
)

// === MPI-3 SHM
//
// Historically, MPI as a message passing framework is often used in combination with other shared-memory frameworks such as OpenMP or pthreads to optimize communication within processes in a node. MPI-3 SHM (shared memory) is a capability introduced in MPI-3 to optimize intra-node communication within MPI RMA windows. This leads to the rise of MPI+MPI approach in distributed programming @zhou. In MPI-3, *shared-memory windows* can be created via `MPI_Win_allocate_shared`. Shared memory windows can be used for both one-sided communication and shared memory access. Besides using MPI-RMA facilities for communication and synchronization in these *shared-memory windows*, other communication and synchronization mechanisms provided by other shared-memory frameworks such as C++11 atomics can also be used. Typically, C++11 atomics allows for much more efficient communication and synchronization compared to MPI-RMA. Therefore, MPI-3 SHM can be used as an optimization for intra-node communication within MPI RMA programs. A general approach in using shared memory windows with tradition MPI RMA is discussed further in @zhou.
//
== Pure MPI approach of porting shared memory algorithms

// === Pure MPI

In pure MPI, we use MPI exclusively for communication and synchronization. With MPI RMA, the communication calls that we utilize are:
- Remote read: `MPI_Get`
- Remote write: `MPI_Put`
- Remote accumulation: `MPI_Accumulate`, `MPI_Get_accumulate`, `MPI_Fetch_and_op` and `MPI_Compare_and_swap`.

For lock-free synchronization, we choose to use *passive target synchronization* with `MPI_Win_lock_all`/`MPI_Win_unlock_all`.

In the MPI-3 specification @mpi-3.1, these functions are specified as follows:

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Specification of `MPI_Win_lock_all` and `MPI_Win_unlock_all`],
  table(
    columns: (1fr, 2.5fr),
    table.header([*Operation*], [*Usage*]),
    [`MPI_Win_lock_all`],
    [Starts and RMA access epoch to all processes in a memory window, with a lock type of `MPI_LOCK_SHARED`. The calling process can access the window memory on all processes in the memory window using RMA operations. This routine is not collective.],

    [`MPI_Win_unlock_all`],
    [Matches with an `MPI_Win_lock_all` to unlock a window previously locked by that `MPI_Win_lock_all`.],
  ),
)

The reason we choose this is 3-fold:
- Unlike *active target synchronization*, *passive target synchronization* does not require the process whose memory is being accessed by an MPI RMA communication call to participate in. This is in line with our intention to use MPI RMA to easily model irregular applications like MPSCs.
- Unlike *active target synchronization*, `MPI_Win_lock_all` and `MPI_Win_unlock_all` do not need to wait for a matching synchronization call in the target process, and thus, is not delayed by the target process.
- Unlike *passive target synchronization* with `MPI_Win_lock`/`MPI_Win_unlock`, multiple calls of `MPI_Win_lock_all` can succeed concurrently, so one process needing to issue MPI RMA communication calls do not block others.

An example of our pure MPI approach with `MPI_Win_lock_all`/`MPI_Win_unlock_all`, inspired by @dinan, is illustrated in the following:

#figure(
  kind: "algorithm",
  supplement: "Listing",
  caption: "An example snippet showcasing our synchronization approach in MPI RMA",
  [
    ```cpp
    MPI_Win_lock_all(0, win);

    MPI_Get(...); // Remote get
    MPI_Put(...); // Remote put
    MPI_Accumulate(..., MPI_REPLACE, ...); // Atomic put
    MPI_Get_accumulate(..., MPI_NO_OP, ...); // Atomic get
    MPI_Fetch_and_op(...); // Remote fetch-and-op
    MPI_Compare_and_swap(...); // Remote compare and swap
    ...

    MPI_Win_flush(...); // Make previous RMA operations take effects
    MPI_Win_flush_local(...); // Make previous RMA operations take effects locally
    ...

    MPI_Win_unlock_all(win);
    ```
  ],
)

#figure(
  image("/static/images/mpi_win_lock_all.png"),
  caption: [An illustration of our synchronization approach in MPI RMA],
)

// === MPI+MPI
//
// MPI is highly optimized for inter-node communication, and in recent years, there is also a trend to use MPI both for intra-node communication @mpi-cpp @zhou. MPI-3 has introduced many improvements to MPI RMA to make this scheme feasible. Compared to pure MPI, MPI+MPI can be more efficient because the fact that some processes locating on the same node is exploited to improve communication.
//
// The general approach is as follows:
// 1. `MPI_Comm_split_type` is used with `MPI_COMM_TYPE_SHARED` to split the communicator to shared-memory communicator.
// 2. `MPI_Win_allocate_shared` is called on each shared-memory communicator to obtain a shared-memory window.
// 3. Inside these shared-memory window, we can use other communication and synchronization primitives that are optimized for shared-memory context.
//
// === MPI+MPI with C++11
//
// As discussed in the previous section, we can use C++11 atomics and synchronization facilities inside shared-memory windows. @mpi-cpp has shown this approach has the potential to obtain significant speedups compared to pure MPI.
