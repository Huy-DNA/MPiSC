= Distributed MPSC queues <distributed-queues>

#import "@preview/lovelace:0.3.0": *
#import "@preview/lemmify:0.1.7": *
#let (
  definition,
  rules: definition-rules,
) = default-theorems("definition", lang: "en")
#let (
  theorem,
  lemma,
  corollary,
  proof,
  rules: theorem-rules,
) = default-theorems("theorem", lang: "en")

#show: theorem-rules
#show: definition-rules

Based on the MPSC queue algorithms we have surveyed in @related-works[], we propose two wait-free distributed MPSC queue algorithms:
- dLTQueue (@naive-LTQueue) is a direct modification of the original LTQueue @ltqueue without any usage of LL/SC, adapted for distributed environment.
- Slotqueue (@slotqueue) is inspired by the timestamp-refreshing idea of LTQueue @ltqueue and repeated-rescan of Jiffy @jiffy. Although it still bears some resemblance to LTQueue, we believe it to be more optimized for distributed context.
We also adapt FastQueue @bcl for MPSC use cases as a distributed baseline MPSC queue algorithm. Notice that FastQueue's dequeuer is now blocking. Further details about our adaptation and proofs of its theoretical aspects are given in the following sections.

In actuality, dLTQueue and Slotqueue are more than simple MPSC algorithms. As hinted in @dfifo-related-works, they are "MPSC queue wrappers", that is, given an SPSC queue implementation, they yield an MPSC implementation. There's one additional constraint: The SPSC interface must support an additional `readFront` operation, which returns the first data item currently in the SPSC queue.

This fact has an important implication: when we're talking about the characteristics (correctness, progress guarantee, performance model, ABA solution and safe memory reclamation scheme) of an MPSC queue wrapper, we're talking about the correctness, progress guarantee, performance model, ABA solution and safe memory reclamation scheme of the wrapper that turns an SPSC queue to an MPSC queue:
- If the underlying SPSC queue is linearizable (which is composable), the resulting MPSC queue is linearizable.
- The resulting MPSC queue's progress guarantee is the weaker guarantee between the wrapper's and the underlying SPSC's.
- If the underlying SPSC queue is safe against ABA problem and memory reclamation, the resulting MPSC queue is also safe against these problems.
- If the underlying SPSC queue is unbounded, the resulting MPSC queue is also unbounded.
- To highlight specifically the performance of "MPSC queue wrappers", we define the theoretical *wrapping overhead*. Roughly speaking:
  - Theoretical performance of the MPSC queue's `enqueue` operation = Theoretical *wrapping overhead* the MPSC queue wrapper impose on `enqueue` + Theoretical performance of the SPSC queue's `enqueue` operation.
  - Theoretical performance of the MPSC queue's `dequeue` operation = Theoretical *wrapping overhead* the MPSC queue wrapper impose on `dequeue` + Theoretical performance of the SPSC queue's `dequeue` operation.

The characteristics of these MPSC queue wrappers and the adapted FastQueue algorithm are summarized in @summary-of-distributed-mpscs. For benchmarking purposes, we use a baseline distributed SPSC introduced in @distributed-spsc in combination with the MPSC queue wrappers. The characteristics of the resulting MPSC queues are also shown in @summary-of-distributed-mpscs.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Characteristic summary of our proposed distributed MPSC queues. #linebreak() (1) $n$ is the number of enqueuers, $R$ stands for *remote operation* and $L$ stands for *local operation*, $F$ stands for the number of failures that cause the FastQueue dequeuer to spin. #linebreak() (2) "`-`" means that it doesn't make sense to talk about a certain aspect of the algorithm. #linebreak() (3) The cells marked with (\*) assumes the underlying SPSC is our baselines SPSC in @distributed-spsc.],
  table(
    columns: (1fr, 1fr, 1fr, 1fr),
    table.header(
      [*MPSC queues*],
      [*FastQueue*],
      [*dLTQueue*],
      [*Slotqueue*],
    ),

    [Correctness], [Linearizable], [Linearizable], [Linearizable],
    [Progress guarantee of dequeue], [Blocking], [Wait-free], [Wait-free],
    [Progress guarantee of enqueue], [Wait-free], [Wait-free], [Wait-free],
    [Dequeue wrapping overhead],
    [-],
    [$Theta(log n) R + Theta(log n) L$],
    [$Theta(n) L$],

    [Enqueue wrapping overhead],
    [-],
    [$Theta(log n) R + Theta(log n) L$],
    [$Theta(1) R + Theta(1) L$],

    [Worst-case #linebreak() time-complexity of #linebreak() dequeue],
    [$(F+1)Theta(1)L$],
    [$Theta(log n) R + Theta(log n) L$ (\*)],
    [$Theta(1) R + Theta(n) L$ (\*)],

    [Worst-case #linebreak() time-complexity of #linebreak() enqueue],
    [$Theta(1)R$],
    [$Theta(log n) R + Theta(log n) L$ (\*)],
    [$Theta(1) R + Theta(1) L$ (\*)],

    [ABA solution],
    [No usage of CAS],
    [Unique timestamp],
    [ABA-safe #linebreak() by default],

    [Memory #linebreak() reclamation],
    [No dynamic memory allocation],
    [No dynamic memory allocation],
    [No dynamic memory allocation],

    [Number of element],
    [Bounded],
    [Depending on the underlying SPSC],
    [Depending on the underlying SPSC],
  ),
) <summary-of-distributed-mpscs>

In the following sections, we present first the one-sided-communication primitives that we assume will be available in our distributed algorithm specification and then our proposed distributed MPSC queue wrappers in detail. Any other discussions about theoretical aspects of these algorithms such as linearizability, progress guarantee, performance model are deferred to @theoretical-aspects[].

In our description, we assume that each process in our program is assigned a unique number as an identifier, which is termed as its *rank*. The numbers are taken from the range of `[0, size - 1]`, with `size` being the number of processes in our program.

== Distributed one-sided-communication primitives in our distributed algorithm specification

Although we use MPI-3 RMA to implement these algorithms, the algorithm specifications themselves are not inherently tied to MPI-3 RMA interfaces. For clarity and convenience in specification, we define the following distributed primitives used in our pseudocode.

#pseudocode-list(line-numbering: none)[
  + *`remote<T>`*
    + A distributed shared variable of type T. The process that physically stores the variable in its local memory is referred to as the *host*. This represents data that can be accessed or modified remotely by other processes.
]
#pseudocode-list(line-numbering: none)[
  + *`void aread_sync(remote<T> src, T* dest)`*
    + Issue a synchronous read of the distributed variable `src` and stores its value into the local memory location pointed to by `dest`. The read is guaranteed to be completed when the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`void aread_sync(remote<T*> src, int index, T* dest)`*
    + Issue a synchronous read of the element at position `index` within the distributed array `src` (where `src` is a pointer to a remotely hosted array of type `T`) and stores the value into the local memory location pointed to by `dest`. The read is guaranteed to be completed when the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`void awrite_sync(remote<T> dest, T* src)`*
    + Issue a synchronous write of the value at the local memory location pointed to by `src` into the distributed variable `dest`. The write is guaranteed to be completed when the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`void awrite_sync(remote<T*> dest, int index, T* src)`*
    + Issue a synchronous write of the value at the local memory location pointed to by `src` into the element at position `index` within the distributed array `dest` (where `dest` is a pointer to a remotely hosted array of type `T`). The write is guaranteed to be completed when the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`void aread_async(remote<T> src, T* dest)`*
    + Issue an asynchronous read of the distributed variable `src` and initiate the transfer of its value into the local memory location pointed to by `dest`. The operation may not be completed when the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`void aread_async(remote<T*> src, int index, T* dest)`*
    + Issue an asynchronous read of the element at position `index` within the distributed array `src` (where `src` is a pointer to a remotely hosted array of type `T`) and initiate the transfer of its value into the local memory location pointed to by `dest`. The operation may not be completed when the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`void awrite_async(remote<T> dest, T* src)`*
    + Issue an asynchronous write of the value at the local memory location pointed to by `src` into the distributed variable `dest`. The operation may not be completed when the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`void awrite_async(remote<T*> dest, int index, T* src)`*
    + Issue an asynchronous write of the value at the local memory location pointed to by `src` into the element at position `index` within the distributed array `dest` (where `dest` is a pointer to a remotely hosted array of type `T`). The operation may not be completed when the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`void flush(remote<T> src)`*
    + Ensure that all read and write operations on the distributed variable `src` (or its associated array) issued before this function call are fully completed by the time the function returns.
]
#pseudocode-list(line-numbering: none)[
  + *`bool compare_and_swap_sync(remote<T> dest, T old_value, T new_value)`*
    + Issue a synchronous compare-and-swap operation on the distributed variable `dest`. The operation atomically compares the current value of `dest` with `old_value`. If they are equal, the value of `dest` is replaced with `new_value`; otherwise, no change is made. The operation is guaranteed to be completed when the function returns, ensuring that the update (if any) is visible to all processes. The type `T` must be a data type with a size of `1`, `2`, `4`, or `8` bytes.
]
#pseudocode-list(line-numbering: none)[
  + *`bool compare_and_swap_sync(remote<T*> dest, int index, T old_value, T new_value)`*
    + Issue a synchronous compare-and-swap operation on the element at position `index` within the distributed array `dest` (where `dest` is a pointer to a remotely hosted array of type `T`). The operation atomically compares the current value of the element at `dest[index]` with `old_value`. If they are equal, the element at `dest[index]` is replaced with new_value; otherwise, no change is made. The operation is guaranteed to be completed when the function returns, ensuring that the update (if any) is visible to all processes. The type `T` must be a data type with a size of `1`, `2`, `4`, or `8`.
]
#pseudocode-list(line-numbering: none)[
  + *`T fetch_and_add_sync(remote<T> dest, T inc)`*
    + Issue a synchronous fetch-and-add operation on the distributed variable `dest`. The operation atomically adds the value `inc` to the current value of `dest`, returning the original value of `dest` (before the addition) to the calling process. The update to `dest` is guaranteed to be completed and visible to all processes when the function returns. The type `T` must be an integral type with a size of `1`, `2`, `4`, or `8` bytes.
]

== FastQueue - An adaptation of BCL's FastQueue as a baseline blocking distributed MPSC

This section presents our straightforward adaptation of BCL's FastQueue to support MPSC use cases. This implementation is used as a comparison baseline for our other algorithms. For fairness, we aim to introduce least possible overhead on the original FastQueue, which is optimized for performance, but not fault-tolerance.

=== Overview

#figure(
  image("/static/images/fastqueue.png"),
  caption: [Adapted FastQueue structure.],
) <fastqueue-structure>

The structure of FastQueue is largely kept intact, except that each entry now holds an additional flag. All data and control variables e.g. the `Last` and `First` indices are hosted at the dequeuer. Enqueuer enqueues an item by FAA-ing the `Last` index to reserve a slot, then it writes the enqueued data and sets the slot's flag to true. The dequeuer dequeues items in the circular buffer in order starting from `First`, but it has to wait for the `is_set` flag to be set to safely dequeue the item. When it has successfully read the value, it unsets the slot's flag and FAA the `First` index. This spinning makes the dequeue operation blocking.

=== Data structure

Below is the types utilized in our MPSC variant of FastQueue.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of the data to be stored.
]

The shared variables and variables local to each enqueuer and dequeuer in our MPSC-variant of FastQueue are as followed.

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `Data`: `remote<data_t*>`
      + An array of `data_t` with the number of entries equal to the predefined capacity.
    + `Flags`: `remote<bool*>`
      + An array of booleans with the number of entries equal to the predefined capacity.
    + `First`: `remote<uint64_t>`
      + A monotonically-increasing counter that points to the index of the first undequeued entry when taken modulo the predefined capacity.
    + `Last`: `remote<uint64_t>`
      + A monotonically-increasing counter that points to the index of the first empty entry when taken modulo the predefined capacity.
]

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `Capacity`: `uint64_t`
        + A read-only variable representing the maximum number of elements that can be present in the queue.
      + `First_buf`: The cached value of `First`.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer-local variables*
      + `Capacity`: `uint64_t`
        + A read-only variable representing the maximum number of elements that can be present in the queue.
      + `Last_buf`: The cached value of `Last`.
  ]
]

Initially, the enqueuers and the dequeuer are initialized as follows:

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer initialization*
      + Initialize `Capacity`.
      + Initialize `First_buf` to `0`.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer initialization*
      + Initialize `Capacity`.
      + Initialize `Last_buf` to `0`.
      + Initialize `First` and `Last`.
      + Initialize `Data` to an array with `Capacity` entries each of which `is_set` is set to `false`.
  ]
]

=== Algorithm

As described, the procedures need to account for changes induced by the introduction of the `is_set` flag to each entry compared the original FastQueue. Other than that, they are kept closest in spirit to the original FastQueue, albeit at the cost of making `dequeue` blocking.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`bool enqueue(data_t v)`],
  )[
    + `old_last = fetch_and_add_sync(Last, 1)`
    + `new_last = old_last + 1`
    + *if* `(new_last - First_buf > Capacity)                                            `
      + `aread_sync(First, &First_buf)`
      + *if* `(new_last - First_buf > Capacity)`
        + `fetch_and_add_sync(Last, -1)`
        + *return* `false`
    + `awrite_sync(Data, Last_buf % Capacity, &v)`
    + `set = true`
    + `awrite_sync(Flags, Last_buf % Capacity, &set)`
    + *return* `true`
  ],
) <fastqueue-enqueue>

To enqueue, the enqueuer reserves an entry in the MPSC queue by FAA-ing the `Last` index (line 1). It then checks if the queue is full and if it is, return `false` (line 3-7). Note the usage of the cached value `First_buf` to lazily fetch the remote `First` value when extremely needed. If the queue is not full, the enqueuer writes out its data (line 8) and sets its entry's flag to `true` (line 10) at its own pace. It then returns `true` to signal success (line 11).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 11,
    booktabs: true,
    numbered-title: [`bool dequeue(data_t* output)`],
  )[
    + `old_first = 0`
    + `aread_sync(First, &old_first)`
    + `new_first = old_first + 1`
    + *if* `(new_first > Last_buf)                                            `
      + `aread_sync(Last, &Last_buf)`
      + *if* `(new_first > Last_buf)`
        + *return* `false`
    + `flag = false`
    + *do*
      + `aread_sync(Flags, old_first % Capacity, &flag)`
      + *while* `(!flag)`
    + `aread_sync(Data, old_first % Capacity, output)`
    + `unset = false`
    + `awrite_sync(Flags, old_first % Capacity, &unset)`
    + `awrite_sync(First, &new_first)`
    + *return* `true`

  ],
) <fastqueue-dequeue>

To dequeue, the dequeuer fetches the `First` remote variable to decide which item to dequeue next (line 12-14). If the queue is empty, it returns `false` (line 15-18). To read the value at `First`, the dequeuer spins until it sees that the corresponding entry is ready (line 20-22). When the entry is ready, it reads the corresponding data (line 23) and resets the flag (line 24-25). It signals success by swinging the `First` index to the next value and return `true` (line 26-27).

== A simple baseline distributed SPSC <distributed-spsc>

For prototyping, the two MPSC queue wrapper algorithms we propose here both utilize a baseline distributed SPSC data structure, which we will present first. For implementation simplicity, we present a bounded SPSC, effectively make our proposed algorithms support only a bounded number of elements. However, one can trivially substitute another distributed unbounded SPSC to make our proposed algorithms support an unbounded number of elements, as long as this SPSC supports the same interface as ours.

Placement-wise, all queue data in this SPSC is hosted on the enqueuer while the control variables i.e. `First` and `Last`, are hosted on the dequeuer.

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Types*
      + `data_t` = The type of data stored.
  ]

  #pseudocode-list(line-numbering: none)[
    + *Shared variables*
      + `First`: `remote<uint64_t>`
        + The index of the last undequeued entry.
        + Hosted at the dequeuer.
      + `Last`: `remote<uint64_t>`
        + The index of the last unenqueued entry.
        + Hosted at the dequeuer.
      + `Data`: `remote<data_t*>`
        + An array of `data_t` of some known capacity.
        + Hosted at the enqueuer.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `Capacity`: A read-only value indicating the capacity of the SPSC.
      + `First_buf`: The cached value of `First`.
      + `Last_buf`: The cached value of `Last`.
  ]

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer-local variables*
      + `Capacity`: A read-only value indicating the capacity of the SPSC.
      + `First_buf`: The cached value of `First`.
      + `Last_buf`: The cached value of `Last`.
  ]
]

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer initialization*
      + Initialize `First` and `Last` to `0`.
      + Initialize `Capacity`.
      + Allocate array in `Data`.
      + Initialize `First_buf = Last_buf = 0`.
  ]
  #colbreak()
  #pseudocode-list(line-numbering: none)[
    + *Dequeuer initialization*
      + Initialize `Capacity`.
      + Initialize `First_buf = Last_buf = 0`.
  ]
]

The procedures of the enqueuer are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`bool spsc_enqueue(data_t v)`],
  )[
    + `new_last = Last_buf + 1`
    + *if* `(new_last - First_buf > Capacity)                                            `
      + `aread_sync(First, &First_buf)`
      + *if* `(new_last - First_buf > Capacity)`
        + *return* `false`
    + `awrite_sync(Data, Last_buf % Capacity, &v)`
    + `awrite_sync(Last, &new_last)`
    + `Last_buf = new_last`
    + *return* `true`
  ],
) <spsc-enqueue>

`spsc_enqueue` first computes the new `Last` value (line 1). If the queue is full as indicating by the difference the new `Last` value and `First-buf` (line 2), there can still be the possibility that some elements have been dequeued but `First-buf` hasn't been synced with `First` yet, therefore, we first refresh the value of `First-buf` by fetching from `First` (line 3). If the queue is still full (line 4), we signal failure (line 5). Otherwise, we proceed to write the enqueued value to the entry at `Last_buf % Capacity` (line 6), increment `Last` (line 7), update the value of `Last_buf` (line 8) and signal success (line 9).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 9,
    booktabs: true,
    numbered-title: [`bool spsc_readFront`#sub(`e`)`(data_t* output)`],
  )[
    + *if* `(First_buf >= Last_buf)                                           `
      + *return* `false`
    + `aread_sync(First, &First_buf)`
    + *if* `(First_buf >= Last_buf)                                           `
      + *return* `false`
    + `aread_sync(Data, First_buf % Capacity, output)`
    + *return* `true`
  ],
) <spsc-enqueue-readFront>

`spsc_readFront`#sub(`e`) first checks if the SPSC is empty based on the difference between `First_buf` and `Last_buf` (line 10). Note that if this check fails, we signal failure immediately (line 11) without refetching either `First` or `Last`. This suffices because `Last` cannot be out-of-sync with `Last_buf` as we're the enqueuer and `First` can only increase since the last refresh of `First_buf`, therefore, if we refresh `First` and `Last`, the condition on line 10 would return `false` anyways. If the SPSC is not empty, we refresh `First` and re-perform the empty check (line 12-14). If the SPSC is again not empty, we read the queue entry at `First_buf % Capacity` into `output` (line 15) and signal success (line 16).

The procedures of the dequeuer are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 14,
    booktabs: true,
    numbered-title: [`bool spsc_dequeue(data_t* output)`],
  )[
    + `new_first = First_buf + 1`
    + *if* `(new_first > Last_buf)                                            `
      + `aread_sync(Last, &Last_buf)`
      + *if* `(new_first > Last_buf)`
        + *return* `false`
    + `aread_sync(Data, First_buf % Capacity, output)`
    + `awrite_sync(First, &new_first)`
    + `First_buf = new_first`
    + *return* `true`

  ],
) <spsc-dequeue>

`spsc_dequeue` first computes the new `First` value (line 15). If the queue is empty as indicating by the difference the new `First` value and `Last-buf` (line 16), there can still be the possibility that some elements have been enqueued but `Last-buf` hasn't been synced with `Last` yet, therefore, we first refresh the value of `Last-buf` by fetching from `Last` (line 17). If the queue is still empty (line 18), we signal failure (line 19). Otherwise, we proceed to read the top value at `First_buf % Capacity` (line 20) into `output`, increment `First` (line 21) - effectively dequeue the element, update the value of `First_buf` (line 22) and signal success (line 23).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 23,
    booktabs: true,
    numbered-title: [`bool spsc_readFront`#sub(`d`)`(data_t* output)`],
  )[
    + *if* `(First_buf >= Last_buf)                                               `
      + `aread_sync(Last, &Last_buf)`
      + *if* `(First_buf >= Last_buf)`
        + *return* `false`
    + `aread_sync(Data, First_buf % Capacity, output)`
    + *return* `true`

  ],
) <spsc-dequeue-readFront>

`spsc_readFront`#sub(`d`) first checks if the SPSC is empty based on the difference between `First_buf` and `Last_buf` (line 24). If this check fails, we refresh `Last_buf` (line 25) and recheck (line 26). If the recheck fails, signal failure (line 27). If the SPSC is not empty, we read the queue entry at `First_buf % Capacity` into `output` (line 28) and signal success (line 29).

== dLTQueue - Modified distributed LTQueue without LL/SC <naive-LTQueue>

This algorithm presents our most straightforward effort to port LTQueue @ltqueue to distributed context. The main challenge is that LTQueue uses LL/SC as the universal atomic instruction and also an ABA solution, but LL/SC is not available in distributed programming environments. We have to replace any usage of LL/SC in the original LTQueue algorithm. Compare-and-swap is unavoidable in distributed MPSC queues, so we use the well-known monotonic timestamp scheme to guard against ABA problem.

=== Overview

The structure of our dLTQueue is shown as in @modified-ltqueue-tree.

We differentiate between 2 types of nodes: *enqueuer nodes* (represented as the rectangular boxes at the bottom of @modified-ltqueue-tree) and normal *tree nodes* (represented as the circular boxes in @modified-ltqueue-tree).

Each enqueuer node corresponds to an enqueuer. Each time the local SPSC is enqueued with a value, the enqueuer timestamps the value using a distributed counter shared by all enqueuers. An enqueuer node stores the SPSC local to the corresponding enqueuer and a `min_timestamp` value which is the minimum timestamp inside the local SPSC.

Each tree node stores the rank of an enqueuer process. This rank corresponds to the enqueuer node with the minimum timestamp among the node's children's ranks. The tree node that's attached to an enqueuer node is called a *leaf node*, otherwise, it's called an *internal node*.

Note that if a local SPSC is empty, the `min_timestamp` variable of the corresponding enqueuer node is set to `MAX_TIMESTAMP` and the corresponding leaf node's rank is set to `DUMMY_RANK`.

#place(
  center + top,
  float: true,
  scope: "parent",
  [#figure(
      kind: "image",
      supplement: "Image",
      image("/static/images/modified-ltqueue.png"),
      caption: [
        dLTQueue's structure.
      ],
    ) <modified-ltqueue-tree>
  ],
)

Placement-wise:
- The *enqueuer nodes* are hosted at the corresponding *enqueuer*.
- All the *tree nodes* are hosted at the *dequeuer*.
- The distributed counter, which the enqueuers use to timestamp their enqueued value, is hosted at the *dequeuer*.

=== Data structure

Below is the types utilized in dLTQueue.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of the data to be stored.
    + `spsc_t` = The type of the SPSC, this is assumed to be the distributed SPSC in @distributed-spsc.
    + `rank_t` = The type of the rank of an enqueuer process tagged with a unique timestamp (version) to avoid ABA problem.
      + *struct*
        + `value`: `uint32_t`
        + `version`: `uint32_t`
      + *end*
    + `timestamp_t` = The type of the timestamp tagged with a unique timestamp (version) to avoid ABA problem.
      + *struct*
        + `value`: `uint32_t`
        + `version`: `uint32_t`
      + *end*
    + `node_t` = The type of a tree node.
      + *struct*
        + `rank`: `rank_t`
      + *end*
]

The shared variables in our LTQueue version are as followed.

Note that we have described a very specific and simple way to organize the tree nodes in dLTQueue in a min-heap-like array structure hosted on the sole dequeuer. We will resume our description of the related tree-structure procedures `parent()` (@ltqueue-parent), `children()` (@ltqueue-children), `leafNodeIndex()` (@ltqueue-leaf-node-index) with this representation in mind. However, our algorithm doesn't strictly require this representation and can be subtituted with other more-optimized representations & distributed placements, as long as the similar tree-structure procedures are supported.

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `Counter`: `remote<uint64_t>`
      + A distributed counter shared by the enqueuers. Hosted at the dequeuer.
    + `Tree_size`: `uint64_t`
      + A read-only variable storing the number of tree nodes present in the dLTQueue.
    + `Nodes`: `remote<node_t>`
      + An array with `Tree_size` entries storing all the tree nodes present in the dLTQueue shared by all processes.
      + Hosted at the dequeuer.
      + This array is organized in a similar manner as a min-heap: At index `0` is the root node. For every index $i gt 0$, $floor((i - 1) / 2)$ is the index of the parent of node $i$. For every index $i gt 0$, $2i + 1$ and $2i + 2$ are the indices of the children of node $i$.
    + `Dequeuer_rank`: `uint32_t`
      + The rank of the dequeuer process. This is read-only.
    + `Timestamps`: A read-only *array* `[0..size - 2]` of `remote<timestamp_t>`, with `size` being the number of processes.
      + The entry at index $i$ corresponds to the `Min_timestamp` distributed variable at the enqueuer with an order of $i$.
]

Similar to the fact that each process in our program is assigned a rank, each enqueuer process in our program is assigned an *order*. The following procedure computes an enqueuer's order based on its rank:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`uint32_t enqueuerOrder(uint32_t enqueuer_rank)`],
  )[
    + *return* `enqueuer_rank > Dequeuer_rank ? enqueuer_rank - 1 : enqueuer_rank`
  ],
) <ltqueue-enqueuer-order>

This procedure is rather straightforward: Each enqueuer is assigned an order in the range `[0, size - 2]`, with `size` being the number of processes and the total ordering among the enqueuers based on their ranks is the same as the total ordering among the enqueuers based on their orders.

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `Enqueuer_count`: `uint64_t`
        + The number of enqueuers.
      + `Self_rank`: `uint32_t`
        + The rank of the current enqueuer process.
      + `Min_timestamp`: `remote<timestamp_t>`
      + `Spsc`: `spsc_t`
        + This SPSC is synchronized with the dequeuer.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer-local variables*
      + `Enqueuer_count`: `uint64_t`
        + The number of enqueuers.
      + `Spscs`: *array* of `spsc_t` with `Enqueuer_count` entries.
        + The entry at index $i$ corresponds to the `Spsc` at the enqueuer with an order of $i$.
  ]
]

Initially, the enqueuers and the dequeuer are initialized as follows:

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer initialization*
      + Initialize `Enqueuer_count`, `Self_rank` and `Dequeuer_rank`.
      + Initialize `Spsc` to the initial state.
      + Initialize `Min_timestamp` to `timestamp_t {MAX_TIMESTAMP, 0}`.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer initialization*
      + Initialize `Enqueuer_count`, `Self_rank` and `Dequeuer_rank`.
      + Initialize `Counter` to `0`.
      + Initialize `Tree_size` to `Enqueuer_count * 2`.
      + Initialize `Nodes` to an array with `Tree_size` entries. Each entry is initialized to `node_t {DUMMY_RANK}`.
      + Initialize `Spscs`, synchronizing each entry with the corresponding enqueuer.
      + Initialize `Timestamps`, synchronizing each entry with the corresponding enqueuer.
  ]
]

=== Algorithm

We first present the tree-structure utility procedures that are shared by both the enqueuer and the dequeuer:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 1,
    booktabs: true,
    numbered-title: [`uint32_t parent(uint32_t index)`],
  )[
    + *return* `(index - 1) / 2                                                   `
  ],
) <ltqueue-parent>

`parent` returns the index of the parent tree node given the node with index `index`. These indices are based on the shared `Nodes` array. Based on how we organize the `Nodes` array, the index of the parent tree node of `index` is `(index - 1) / 2`.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 2,
    booktabs: true,
    numbered-title: [`vector<uint32_t> children(uint32_t index)`],
  )[
    + `left_child = index * 2 + 1                                                  `
    + `right_child = left_child + 1`
    + `res = vector<uint32_t>()`
    + *if* `(left_child >= Tree_size)`
      + *return* `res`
    + `res.push(left_child)`
    + *if* `(right_child >= Tree_size)`
      + *return* `res`
    + `res.push(right_child)`
    + *return* `res`
  ],
) <ltqueue-children>

Similarly, `children` returns all indices of the child tree nodes given the node with index `index`. These indices are based on the shared `Nodes` array. Based on how we organize the `Nodes` array, these indices can be either `index * 2 + 1` or `index * 2 + 2`.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 12,
    booktabs: true,
    numbered-title: [`uint32_t leafNodeIndex(uint32_t enqueuer_rank)`],
  )[
    + *return* `Tree_size + enqueuerOrder(enqueuer_rank)                         `
  ],
) <ltqueue-leaf-node-index>

`leafNodeIndex` returns the index of the leaf node that's logically attached to the enqueuer node with rank `enqueuer_rank` as in @modified-ltqueue-tree.

The followings are the enqueuer procedures.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 13,
    booktabs: true,
    numbered-title: [`bool enqueue(data_t value)`],
  )[
    + `timestamp = fetch_and_add_sync(Counter, 1)                                        `
    + `spsc_enqueue(&Spsc, (value, timestamp))`
    + `propagate`#sub(`e`)`()`
  ],
) <ltqueue-enqueue>

To enqueue a value, `enqueue` first obtains a count by `FAA` the distributed counter `Counter` (line 14). Then, we enqueue the data tagged with the timestamp into the local SPSC (line 15). Finally, `enqueue` propagates the changes by invoking `propagate`#sub(`e`)`()` (line 16).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 17,
    booktabs: true,
    numbered-title: [`void propagate`#sub(`e`)`()`],
  )[
    + *if* `(!refreshTimestamp`#sub(`e`)`())                                                `
      + `refreshTimestamp`#sub(`e`)`()`
    + *if* `(!refreshLeaf`#sub(`e`)`())`
      + `refreshLeaf`#sub(`e`)`()`
    + `current_node_index = leafNodeIndex(Self_rank)`
    + *repeat*
      + `current_node_index = parent(current_node_index)`
      + *if* `(!refresh`#sub(`e`)`(current_node_index))`
        + `refresh`#sub(`e`)`(current_node_index)`
    + *until* `current_node_index == 0`
  ],
) <ltqueue-enqueue-propagate>

The `propagate`#sub(`e`) procedure is responsible for propagating SPSC updates up to the root node as a way to notify other processes of the newly enqueued item. It is split into 3 phases: Refreshing of `Min_timestamp` in the enqueuer node (line 18-19), refreshing of the enqueuer's leaf node (line 20-21), refreshing of internal nodes (line 23-27). On line 20-27, we refresh every tree node that lies between the enqueuer node and the root node.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 27,
    booktabs: true,
    numbered-title: [`bool refreshTimestamp`#sub(`e`)`()`],
  )[
    + `min_timestamp = timestamp_t {}`
    + `aread_sync(Min_timestamp, &min_timestamp)`
    + `{old-timestamp, old-version} = min_timestamp                                 `
    + `front = (data_t {}, timestamp_t {})`
    + `is_empty = spsc_readFront(Spsc, &front)`
    + *if* `(is_empty)`
      + *return* `compare_and_swap_sync(Min_timestamp,
timestamp_t {old-timestamp, old-version},
timestamp_t {MAX_TIMESTAMP, old-version + 1})`
    + *else*
      + *return* `compare_and_swap_sync(Min_timestamp,
timestamp_t {old-timestamp, old-version},
timestamp_t {front.timestamp, old-version + 1})`
  ],
) <ltqueue-enqueue-refresh-timestamp>

The `refreshTimestamp`#sub(`e`) procedure is responsible for updating the `Min_timestamp` of the enqueuer node. It simply looks at the front of the local SPSC (line 310 and CAS `Min_timestamp` accordingly (line 33-36).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 36,
    booktabs: true,
    numbered-title: [`bool refreshNode`#sub(`e`)`(uint32_t current_node_index)`],
  )[
    + `current_node = node_t {}                                                      `
    + `aread_sync(Nodes, current_node_index, &current_node)`
    + `{old-rank, old-version} = current_node.rank`
    + `min_rank = DUMMY_RANK`
    + `min_timestamp = MAX_TIMESTAMP`
    + *for* `child_node_index` in `children(current_node)`
      + `child_node = node_t {}`
      + `aread_sync(Nodes, child_node_index, &child_node)`
      + `{child_rank, child_version} = child_node`
      + *if* `(child_rank == DUMMY_RANK)` *continue*
      + `child_timestamp = timestamp_t {}`
      + `aread_sync(Timestamps[enqueuerOrder(child_rank)], &child_timestamp)`
      + *if* `(child_timestamp < min_timestamp)`
        + `min_timestamp = child_timestamp`
        + `min_rank = child_rank`
    + *return* `compare_and_swap_sync(Nodes, current_node_index,
node_t {rank_t {old_rank, old_version}},
node_t {rank_t {min_rank, old_version + 1}})`
  ],
) <ltqueue-enqueue-refresh-node>

The `refreshNode`#sub(`e`) procedure is responsible for updating the ranks of the internal nodes affected by the enqueue. It loops over the children of the current internal nodes (line 42). For each child node, we read the rank stored in it (line 44), if the rank is not `DUMMY_RANK`, we proceed to read the value of `Min_timestamp` of the enqueuer node with the corresponding rank (line 48). At the end of the loop, we obtain the rank stored inside one of the child nodes that has the minimum timestamp stored in its enqueuer node (line 50-51). We then try to CAS the rank inside the current internal node to this rank.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 52,
    booktabs: true,
    numbered-title: [`bool refreshLeaf`#sub(`e`)`()`],
  )[
    + `leaf_node_index = leafNodeIndex(Self_rank)             `
    + `leaf_node = node_t {}`
    + `aread_sync(Nodes, leaf_node_index, &leaf_node)`
    + `{old_rank, old_version} = leaf_node.rank`
    + `min_timestamp = timestamp_t {}`
    + `aread_sync(Min_timestamp, &min_timestamp)`
    + `timestamp = min_timestamp.timestamp`
    + *return* `compare_and_swap_sync(Nodes, leaf_node_index,
node_t {rank_t {old-rank, old-version}},
node_t {timestamp == MAX ? DUMMY_RANK : Self_rank, old_version + 1})`
  ],
) <ltqueue-enqueue-refresh-leaf>

The `refreshLeaf`#sub(`e`) procedure is responsible for updating the rank of the leaf node affected by the enqueue. It simply reads the value of `Min_timestamp` of the enqueuer node it's logically attached to (line 58) and CAS the leaf node's rank accordingly (line 60).

The followings are the dequeuer procedures.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 60,
    booktabs: true,
    numbered-title: [`bool dequeue(data_t* output)`],
  )[
    + `root_node = node_t {}                                                     `
    + `aread_sync(Nodes, 0, &root_node)`
    + `{rank, version} = root_node.rank`
    + *if* `(rank == DUMMY_RANK)` *return* `false`
    + `output_with_timestamp = (data_t {}, timestamp_t {})`
    + *if* `(!spsc_dequeue(&Spscs[enqueuerOrder(rank)]),
    &output_with_timestamp))`
      + *return* `false`
    + `*output = output_with_timestamp.data`
    + `propagate`#sub(`d`)`(rank)`
    + *return* `true`
  ],
) <ltqueue-dequeue>

To dequeue a value, `dequeue` reads the rank stored inside the root node (line 62). If the rank is `DUMMY_RANK`, the MPSC queue is treated as empty and failure is signaled (line 64). Otherwise, we invoke `spsc_dequeue` on the SPSC of the enqueuer with the obtained rank (line 66). We then extract out the real data and set it to `output` (line 68). We finally propagate the dequeue from the enqueuer node that corresponds to the obtained rank (line 69) and signal success (line 70).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 70,
    booktabs: true,
    numbered-title: [`void propagate`#sub(`d`)`(uint32_t enqueuer_rank)`],
  )[
    + *if* `(!refreshTimestamp`#sub(`d`)`(enqueuer_rank))                                              `
      + `refreshTimestamp`#sub(`d`)`(enqueuer_rank)`
    + *if* `(!refreshLeaf`#sub(`d`)`(enqueuer_rank))`
      + `refreshLeaf`#sub(`d`)`(enqueuer_rank)`
    + `current_node_index = leafNodeIndex(enqueuer_rank)`
    + *repeat*
      + `current_node_index = parent(current_node_index)`
      + *if* `(!refresh`#sub(`d`)`(current_node_index))`
        + `refresh`#sub(`d`)`(current_node_index)`
    + *until* `current_node_index == 0`
  ],
) <ltqueue-dequeue-propagate>

The `propagate`#sub(`d`) procedure is similar to `propagate`#sub(`e`), with appropriate changes to accommodate the dequeuer.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 80,
    booktabs: true,
    numbered-title: [`bool refreshTimestamp`#sub(`d`)`(uint32_t enqueuer_rank)`],
  )[
    + `enqueuer_order = enqueuerOrder(enqueuer_rank)`
    + `min_timestamp = timestamp_t {}`
    + `aread_sync(Timestamps, enqueuer_order, &min_timestamp)`
    + `{old-timestamp, old-version} = min_timestamp                                 `
    + `front = (data_t {}, timestamp_t {})`
    + `is_empty = spsc_readFront(&Spscs[enqueuer_order], &front)`
    + *if* `(is_empty)`
      + *return* `compare_and_swap_sync(Timestamps, enqueuer_order,
timestamp_t {old-timestamp, old-version},
timestamp_t {MAX_TIMESTAMP, old-version + 1})`
    + *else*
      + *return* `compare_and_swap_sync(Timestamps, enqueuer_order,
timestamp_t {old-timestamp, old-version},
timestamp_t {front.timestamp, old-version + 1})`
  ],
) <ltqueue-dequeue-refresh-timestamp>

The `refreshTimestamp`#sub(`d`) procedure is similar to `refreshTimestamp`#sub(`e`), with appropriate changes to accommodate the dequeuer.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 90,
    booktabs: true,
    numbered-title: [`bool refreshNode`#sub(`d`)`(uint32_t current_node_index)`],
  )[
    + `current_node = node_t {}                                                      `
    + `aread_sync(Nodes, current_node_index, &current_node)`
    + `{old-rank, old-version} = current_node.rank`
    + `min_rank = DUMMY_RANK`
    + `min_timestamp = MAX_TIMESTAMP`
    + *for* `child_node_index` in `children(current_node)`
      + `child_node = node_t {}`
      + `aread_sync(Nodes, child_node_index, &child_node)`
      + `{child_rank, child_version} = child_node`
      + *if* `(child_rank == DUMMY_RANK)` *continue*
      + `child_timestamp = timestamp_t {}`
      + `aread_sync(Timestamps[enqueuerOrder(child_rank)], &child_timestamp)`
      + *if* `(child_timestamp < min_timestamp)`
        + `min_timestamp = child_timestamp`
        + `min_rank = child_rank`
    + *return* `compare_and_swap_sync(Nodes, current_node_index,
node_t {rank_t {old_rank, old_version}},
node_t {rank_t {min_rank, old_version + 1}})`
  ],
) <ltqueue-dequeue-refresh-node>

The `refreshNode`#sub(`d`) procedure is similar to `refreshNode`#sub(`e`), with appropriate changes to accommodate the dequeuer.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 106,
    booktabs: true,
    numbered-title: [`bool refreshLeaf`#sub(`d`)`(uint32_t enqueuer_rank)`],
  )[
    + `leaf_node_index = leafNodeIndex(enqueuer_rank)             `
    + `leaf_node = node_t {}`
    + `aread_sync(Nodes, leaf_node_index, &leaf_node)`
    + `{old_rank, old_version} = leaf_node.rank`
    + `min_timestamp = timestamp_t {}`
    + `aread_sync(Timestamps, enqueuerOrder(enqueuer_rank), &min_timestamp)`
    + `timestamp = min_timestamp.timestamp`
    + *return* `compare_and_swap_sync(Nodes, leaf_node_index,
node_t {rank_t {old-rank, old-version}},
node_t {timestamp == MAX ? DUMMY_RANK : Self_rank, old_version + 1})`
  ],
) <ltqueue-dequeue-refresh-leaf>

The `refreshLeaf`#sub(`d`) procedure is similar to `refreshLeaf`#sub(`e`), with appropriate changes to accommodate the dequeuer.

== Slotqueue - Optimized dLTQueue for distributed context <slotqueue>

Even though the straightforward dLTQueue algorithm we have ported in @naive-LTQueue pretty much preserve the original algorithm's characteristics, i.e. wait-freedom and time complexity of $Theta(log n)$ for both `enqueue` and `dequeue` operations (which we will prove in @theoretical-aspects[]), we have to be aware that this is $Theta(log n)$ remote operations, which is potentially expensive and a bottleneck in the algorithm.

Therefore, to be more suitable for distributed context, we propose a new algorithm that's inspired by LTQueue, in which both `enqueue` and `dequeue` only perform a constant number of remote operations, at the cost of `dequeue` having to perform $Theta(n)$ local operations, where $n$ is the number of enqueuers. Because remote operations are much more expensive, this might be a worthy tradeoff.

=== Overview

The structure of Slotqueue is shown as in @slotqueue-structure.

Each enqueuer hosts a distributed SPSC as in dLTQueue (@naive-LTQueue). The enqueuer when enqueues a value to its local SPSC will timestamp the value using a distributed counter hosted at the dequeuer.

Additionally, the dequeuer hosts an array whose entries each corresponds with an enqueuer. Each entry stores the minimum timestamp of the local SPSC of the corresponding enqueuer.

#figure(
  image("/static/images/slotqueue.png"),
  caption: [Basic structure of Slotqueue.],
) <slotqueue-structure>


=== Data structure

We first introduce the types and shared variables utilized in Slotqueue.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of data stored.
    + `timestamp_t` = `uint64_t`
    + `spsc_t` = The type of the SPSC each enqueuer uses, this is assumed to be the distributed SPSC in @distributed-spsc.
]

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `Slots`: `remote<timestamp_t*>`
      + An array of `timestamp_t` with the number of entries equal to the number of enqueuers.
      + Hosted at the dequeuer.
    + `Counter`: `remote<uint64_t>`
      + A distributed counter.
      + Hosted at the dequeuer.
]

Similar to the idea of assigning an order to each enqueuer in dLTQueue, the following procedure computes an enqueuer's order based on its rank:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`uint64_t enqueuerOrder(uint64_t enqueuer_rank)`],
  )[
    + *return* `enqueuer_rank > Dequeuer_rank ? enqueuer_rank - 1 : enqueuer_rank`
  ],
) <slotqueue-enqueuer-order>

Again, each enqueuer is assigned an order in the range `[0, size - 2]`, with `size` being the number of processes and the total ordering among the enqueuers based on their ranks is the same as the total ordering among the enqueuers based on their orders.

Reversely, `enqueuerRank` computes an enqueuer's rank given its order.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 1,
    booktabs: true,
    numbered-title: [`uint64_t enqueuerRank(uint64_t enqueuer_order)`],
  )[
    + *return* `enqueuer_order >= Dequeuer_rank ? enqueuer_order + 1 : enqueuer_order                                                       `
  ],
) <slotqueue-enqueuer-rank>

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `Dequeuer_rank`: `uint64_t`
        + The rank of the dequeuer.
      + `Enqueuer_count`: `uint64_t`
        + The number of enqueuers.
      + `Self_rank`: `uint32_t`
        + The rank of the current enqueuer process.
      + `Spsc`: `spsc_t`
        + This SPSC is synchronized with the dequeuer.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer-local variables*
      + `Dequeuer_rank`: `uint64_t`
        + The rank of the dequeuer.
      + `Enqueuer_count`: `uint64_t`
        + The number of enqueuers.
      + `Spscs`: *array* of `spsc_t` with `Enqueuer_count` entries.
        + The entry at index $i$ corresponds to the `Spsc` at the enqueuer with an order of $i$.
  ]
]

Initially, the enqueuer and the dequeuer are initialized as follows.

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer initialization*
      + Initialize `Dequeuer_rank`.
      + Initialize `Enqueuer_count`.
      + Initialize `Self_rank`.
      + Initialize the local `Spsc` to its initial state.
  ]
  #colbreak()
  #pseudocode-list(line-numbering: none)[
    + *Dequeuer initialization*
      + Initialize `Dequeuer_rank`.
      + Initialize `Enqueuer_count`.
      + Initialize `Counter` to 0.
      + Initialize the `Slots` array with size equal to the number of enqueuers and every entry is initialized to `MAX_TIMESTAMP`.
      + Initialize the `Spscs` array, the `i`-th entry corresponds to the `Spsc` variable of the enqueuer of order `i`.
  ]
]

=== Algorithm

The enqueuer operations are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 2,
    booktabs: true,
    numbered-title: [`bool enqueue(data_t v)`],
  )[
    + `timestamp = fetch_and_add_sync(Counter)                                     `
    + *if* `(!spsc_enqueue(&Spsc, (v, timestamp)))` *return* `false`
    + *if* `(!refreshEnqueue(timestamp))`
      + `refreshEnqueue(timestamp)`
    + *return* `true`
  ],
) <slotqueue-enqueue>

To enqueue a value, `enqueue` first obtains a timestamp by FAA-ing the distributed counter (line 3). It then tries to enqueue the value tagged with the timestamp (line 4). At line 5-6, the enqueuer tries to refresh its slot's timestamp.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 7,
    booktabs: true,
    numbered-title: [`bool refreshEnqueue(timestamp_t ts)`],
  )[
    + `enqueuer_order = enqueueOrder(Self_rank)                                     `
    + `front = (data_t {}, timestamp_t {})`
    + `success = spsc_readFront(Spsc, &front)`
    + `new_timestamp = success ? front.timestamp : MAX_TIMESTAMP`
    + *if* `(new_timestamp != ts)`
      + *return* `true`
    + `old_timestamp = timestamp_t {}`
    + `aread_sync(&Slots, enqueuer_order, &old_timestamp)`
    + `success = spsc_readFront(Spsc, &front)`
    + `new_timestamp = success ? front.timestamp : MAX_TIMESTAMP`
    + *if* `(new_timestamp != ts)`
      + *return* `true`
    + *return* `compare_and_swap_sync(Slots, enqueuer_order,
    old_timestamp,
    new_timestamp)`
  ],
) <slotqueue-refresh-enqueue>

`refreshEnqueue`'s responsibility is to refresh the timestamp stores in the enqueuer's slot to potentially notify the dequeuer of its newly-enqueued element. It first reads the current front element (line 10). If the SPSC is empty, the new timestamp is set to `MAX_TIMESTAMP`, otherwise, the front element's timestamp (line 11). If it finds that the front element's timestamp is different from the timestamp `ts` it returns `true` immediately (line 9-13). Otherwise, it reads its slot's old timestamp (line 14) and re-reads the current front element in the SPSC (line 16) to update the new timstamp. Note that similar to line 13, `refreshEnqueue` immediately succeeds if the new timestamp is different from the timestamp `ts` of the element it enqueues (line 19). Otherwise, it tries to CAS its slot's timestamp with the new timestamp (line 20).

The dequeuer operations are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 20,
    booktabs: true,
    numbered-title: [`bool dequeue(data_t* output)`],
  )[
    + `rank = readMinimumRank()                                                    `
    + *if* `(rank == DUMMY_RANK)`
      + *return* `false`
    + `output_with_timestamp = (data_t {}, timestamp_t {})`
    + *if* `(!spsc_dequeue(Spsc, &output_with_timestamp))`
      + *return* `false`
    + `*output = output_with_timestamp.data`
    + *if* `(!refreshDequeue(rank))`
      + `refreshDequeue(rank)`
    + *return* `true`
  ],
) <slotqueue-dequeue>

To dequeue a value, `dequeue` first reads the rank of the enqueuer whose slot currently stores the minimum timestamp (line 21). If the obtained rank is `DUMMY_RANK`, failure is signaled (line 22-23). Otherwise, it tries to dequeue the SPSC of the corresponding enqueuer (line 25). It then tries to refresh the enqueuer's slot's timestamp to potentially notify the enqueuer of the dequeue (line 28-29). It then signals success (line 30).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 30,
    booktabs: true,
    numbered-title: [`uint64_t readMinimumRank()`],
  )[
    + `buffered_slots = timestamp_t[Enqueuer_count] {}                       `
    + *for* `index` *in* `0..Enqueuer_count`
      + `aread_async(Slots, index, &bufferred_slots[index])`
    + `flush(Slots)`
    + *if* every entry in `bufferred_slots` is `MAX_TIMESTAMP`
      + *return* `DUMMY_RANK`
    + *for* `index` *in* `0..Enqueuer_count`
      + `aread_async(Slots, index, &bufferred_slots[index])`
    + `flush(Slots)`
    + `rank = DUMMY_RANK`
    + `min_timestamp = MAX_TIMESTAMP`
    + *for* `index` *in* `0..Enqueuer_count`
      + `timestamp = buffered_slots[index]`
      + *if* `(min_timestamp < timestamp)`
        + `rank = enqueuerRank(index)`
        + `min_timestamp = timestamp`
    + *return* `rank`
  ],
) <slotqueue-read-minimum-rank>

`readMinimumRank`'s main responsibility is to return the rank of the enqueuer from which we can safely dequeue next. It first creates a local buffer to store the value read from `Slots` (line 31). It then performs 2 scans of `Slots` and read every entry into `buffered_slots` (line 32-37). If the first scan finds only `MAX_TIMESTAMP`s, `DUMMY_RANK` is returned (line 36). From there, based on `bufferred_slots`, it returns the rank of the enqueuer whose bufferred slot stores the minimum timestamp (line 42-47).

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 47,
    booktabs: true,
    numbered-title: [`refreshDequeue(rank: int)` *returns* `bool`],
  )[
    + `enqueuer_order = enqueuerOrder(rank)                                `
    + `old_timestamp = timestamp_t {}`
    + `aread_sync(&Slots, enqueuer_order, &old_timestamp)`
    + `front = (data_t {}, timestamp_t {})`
    + `success = spsc_readFront(Spscs[enqueuer_order], &front)`
    + `new_timestamp = success ? front.timestamp : MAX_TIMESTAMP`
    + *return* `compare_and_swap_sync(Slots, enqueuer_order,
    old_timestamp,
    new_timestamp)`
  ],
) <slotqueue-refresh-dequeue>

`refreshDequeue`'s responsibility is to refresh the timestamp of the just-dequeued enqueuer to notify the enqueuer of the dequeue. It first reads the old timestamp of the slot (line 50) and the front element (line 52). If the SPSC is empty, the new timestamp is set to `MAX_TIMESTAMP`, otherwise, it's the front element's timestamp (line 53). It finally tries to CAS the slot with the new timestamp (line 54).
