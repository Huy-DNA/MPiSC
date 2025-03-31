= Distributed MPSCs <distributed-queues>

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

Based on the MPSC algorithms we have surveyed in @related-works[], we propose two wait-free distributed MPSC algorithms:
- One is a direct modification of LTQueue @ltqueue without any usage of LL/SC.
- One is inspired by the timestamp-refreshing idea of LTQueue @ltqueue and repeated-rescan of Jiffy @jiffy. Although it still bears some resemblance to LTQueue, we believe it to be more optimized for distributed context.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Characteristic summary of our proposed distributed MPSCs. $n$ is the number of enqueuers, R stands for *remote operation* and A stands for *atomic operation*],
  table(
    columns: (2fr, 1fr, 1fr),
    table.header(
      [*MPSC*],
      [*LTQueue without LL/SC*],
      [*Optimized distributed LTQueue*],
    ),

    [Correctness], [Linearizable], [Linearizable],
    [Progress guarantee of dequeue], [Wait-free], [Wait-free],
    [Progress guarantee of enqueue], [Wait-free], [Wait-free],
    [Time complexity of dequeue],
    [$O(log n)$ R + $O(log n)$ A],
    [constant R + $O(n)$ A],

    [Time complexity of enqueue],
    [$O(log n)$ R + $O(log n)$ A],
    [constant R + constant A],

    [ABA solution], [Unique timestamp], [No harmful ABA problem],
    [Memory reclamation], [Custom scheme], [Custom scheme],
    [Number of elements], [Unbounded], [Unbounded],
  ),
) <summary-of-distributed-mpscs>

In this section, we present our proposed distributed MPSCs in detail. Any other discussions about theoretical aspects of these algorithms such as linearizability, progress guarantee, time complexity are deferred to @theoretical-aspects[].

== Distributed primitives in pseudocode

Although we use MPI-3 RMA to implement these algorithms, the algorithm specifications themselves are not inherently tied to MPI-3 RMA interfaces. For clarity and convenience in specification, we define the following distributed primitives used in our pseudocode.

`remote<T>`: A distributed shared variable of type T. The process that physically stores the variable in its local memory is referred to as the *host*. This represents data that can be accessed or modified remotely by other processes.

`void aread_sync(remote<T> src, T* dest)`: Issue a synchronous read of the distributed variable `src` and stores its value into the local memory location pointed to by `dest`. The read is guaranteed to be completed when the function returns.

`void aread_sync(remote<T*> src, int index, T* dest)`: Issue a synchronous read of the element at position `index` within the distributed array `src` (where `src` is a pointer to a remotely hosted array of type `T`) and stores the value into the local memory location pointed to by `dest`. The read is guaranteed to be completed when the function returns.

`void awrite_sync(remote<T> dest, T* src)`: Issue a synchronous write of the value at the local memory location pointed to by `src` into the distributed variable `dest`. The write is guaranteed to be completed when the function returns.

`void awrite_sync(remote<T*> dest, int index, T* src)`: Issue a synchronous write of the value at the local memory location pointed to by `src` into the element at position `index` within the distributed array `dest` (where `dest` is a pointer to a remotely hosted array of type `T`). The write is guaranteed to be completed when the function returns.

`void aread_async(remote<T> src, T* dest)`: Issue an asynchronous read of the distributed variable `src` and initiate the transfer of its value into the local memory location pointed to by `dest`. The operation may not be completed when the function returns.

`void aread_async(remote<T*> src, int index, T* dest)`: Issue an asynchronous read of the element at position `index` within the distributed array `src` (where `src` is a pointer to a remotely hosted array of type `T`) and initiate the transfer of its value into the local memory location pointed to by `dest`. The operation may not be completed when the function returns.

`void awrite_async(remote<T> dest, T* src)`: Issue an asynchronous write of the value at the local memory location pointed to by `src` into the distributed variable `dest`. The operation may not be completed when the function returns.

`void awrite_async(remote<T*> dest, int index, T* src)`: Issue an asynchronous write of the value at the local memory location pointed to by `src` into the element at position `index` within the distributed array `dest` (where `dest` is a pointer to a remotely hosted array of type `T`). The operation may not be completed when the function returns.

`void flush(remote<T> src)`: Ensure that all read and write operations on the distributed variable `src` (or its associated array) issued before this function call are fully completed by the time the function returns.

== A basis distributed SPSC

The two algorithms we propose here both utilize a distributed SPSC data structure, which we will present first. For implementation simplicity, we present a bounded SPSC, effectively make our proposed algorithms support only a bounded number of elements. However, one can trivially substitute another distributed unbounded SPSC to make our proposed algorithms support an unbounded number of elements, as long as this SPSC supports the same interface as ours.

Placement-wise, all shared data in this SPSC is hosted on the enqueuer.

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Types*
      + `data_t` = The type of data stored
  ]

  #pseudocode-list(line-numbering: none)[
    + *Shared variables*
      + `First`: `remote<uint64_t>`
        + The index of the last undequeued entry. Hosted at the enqueuer.
      + `Last`: `remote<uint64_t>`
        + The index of the last unenqueued entry. Hosted at the enqueuer.
      + `Data`: `remote<data_t*>`
        + An array of `data_t` of some known capacity. Hosted at the enqueuer.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `Capacity`: A read-only value indicating the capacity of the SPSC
      + `First_buf`: The cached value of `First`
      + `Last_buf`: The cached value of `Last`
  ]

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer-local variables*
      + `Capacity`: A read-only value indicating the capacity of the SPSC
      + `First_buf`: The cached value of `First`
      + `Last_buf`: The cached value of `Last`
  ]
]

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer initialization*
      + Initialize `First` and `Last` to `0`
      + Initialize `Capacity`
      + Allocate array in `Data`
      + `First_buf = Last_buf = 0`
  ]
  #colbreak()
  #pseudocode-list(line-numbering: none)[
    + *Dequeuer initialization*
      + Initialize `Capacity`
      + `First_buf = Last_buf = 0`
  ]
]

The procedures are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`spsc_enqueue(v: data_t)` *returns* `bool`],
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
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`spsc_dequeue()` *returns* `data_t`],
  )[ ],
) <spsc-dequeue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`spsc_readFront` *returns* `data_t`],
  )[ ],
) <spsc-readFront>

== Modified LTQueue without LL/SC

The structure of our modified LTQueue is shown as in @modified-ltqueue-tree.

#place(
  center + top,
  float: true,
  scope: "parent",
  [#figure(
      kind: "image",
      supplement: "Image",
      image("/static/images/modified-ltqueue.png"),
      caption: [
        Modified LTQueue's structure
      ],
    ) <modified-ltqueue-tree>
  ],
)

At the bottom *enqueuer nodes* (represented by the type `enqueuer_t`), besides the local SPSC, the minimum-timestamp among the elements in the SPSC is also stored.

The *internal nodes* store a rank of an enqueuer. This rank corresponds to the enqueuer with the minimum timestamp among the ranks stored in the node's children.

Note that if a local SPSC is empty, the minimum-timestamp of the corresponding enqueuer node is set to `MAX` and the corresponding leaf node's rank is set to a `DUMMY` rank.

Placement-wise:
- The *enqueuer nodes* and thus, the local SPSCs, are hosted at the corresponding *enqueuer*.
- All the *internal nodes* are hosted at the *dequeuer*.
- The distributed counter, which the enqueuers use to timestamp their enqueued value, is hosted at the *dequeuer*.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of the data to be stored in LTQueue
    + `spsc_t` = The type of the local SPSC
    + `rank_t` = The rank of an enqueuer
      + *struct*
        + `value`: `uint32_t`
        + `version`: `uint32_t`
      + *end*
    + `timestamp_t` =
      + *struct*
        + `value`: `uint32_t`
        + `version`: `uint32_t`
      + *end*
    + `enqueuer_t` =
      + *struct*
        + `spsc`: `spsc_t`
        + `min-timestamp`: `timestamp_t`
      + *end*
    + `node_t` = The node type of the tree constructed by LTQueue
      + *struct*
        + `rank`: `rank_t`
      + *end*
]

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `counter`: `uint64_t`
    + `root`: *pointer to* `node_t`
    + `enqueuers`: *array* `[1..n]` *of* `enqueuer_t`
]

#pseudocode-list(line-numbering: none)[
  + *Initialization*
    + `counter = 0`
    + Construct the tree structure and set `root` to the root node
    + Initialize every node in the tree to contain `DUMMY` rank and version `0`
    + Initialize every enqueuer's `timestamp` to `MAX` and version `0`
]

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`enqueue(rank: int, value: data_t)`],
  )[
    + `count = FAA(counter)                                                   `
    + `timestamp = (count, rank)`
    + `spsc_enqueue(enqueuers[rank].spsc, (value, timestamp))`
    + `propagate(rank)`
  ],
) <ltqueue-enqueue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 4,
    booktabs: true,
    numbered-title: [`dequeue()` *returns* `data_t`],
  )[
    + `[rank, version] = root->rank                                              `
    + *if* `(rank == DUMMY)` *return* $bot$
    + `ret = spsc_dequeue(enqueuers[rank].spsc)`
    + `propagate(rank)`
    + *return* `ret.val`
  ],
) <ltqueue-dequeue>

We omit the description of procedures `parent`, `leafNode`, `children`, leaving how the tree is constructed and children-parent relationship is determined to the implementor. The tree structure used by LTQueue is read-only so a wait-free implementation of these procedures is trivial.

After each `enqueue` or `dequeue`, the timestamp-propation procedures are called to propagate the newly-enqueued timestamp from the enqueuer node up to the root node.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 9,
    booktabs: true,
    numbered-title: [`propagate(rank: uint32_t)`],
  )[
    + *if* $not$`refreshTimestamp(rank)                                          `
      + `refreshTimestamp(rank)`
    + *if* $not$`refreshLeaf(rank)`
      + `refreshLeaf(rank)`
    + `currentNode = leafNode(rank)`
    + *repeat*
      + `currentNode = parent(currentNode)`
      + *if* $not$`refresh(currentNode)`
        + `refresh(currentNode)`
    + *until* `currentNode == root`
  ],
) <ltqueue-propagate>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 19,
    booktabs: true,
    numbered-title: [`refresh(currentNode:` *pointer* to `node_t)`],
  )[
    + `[old-rank, old-version] = currentNode->rank                              `
    + `min-rank = DUMMY`
    + `min-timestamp = MAX`
    + *for* `childNode` in `children(currentNode)`
      + `[child-rank, ...] = childNode->rank`
      + *if* `(child-rank == DUMMY)` *continue*
      + `child-timestamp = enqueuers[child-rank].min-timestamp`
      + *if* `(child-timestamp < min-timestamp)`
        + `min-timestamp = child-timestamp`
        + `min-rank = child-rank`
    + `CAS(&currentNode->rank, [old-rank, old-version], [min-rank, old-version + 1])`
  ],
) <ltqueue-refresh>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 30,
    booktabs: true,
    numbered-title: [`refreshTimestamp(rank: uint32_t)`],
  )[
    + `[old-timestamp, old-version] = enqueuers[rank].timestamp`
    + `front = spsc_readFront(enqueuers[rank].spsc)`
    + *if* `(front == `$bot$`)`
      + `CAS(&enqueuers[rank].timestamp, [old-timestamp, old-version], [MAX, old-version + 1])`
    + *else*
      + `CAS(&enqueuers[rank].timestamp, [old-timestamp, old-version], [front.timestamp, old-version + 1])`
  ],
) <ltqueue-refresh-timestamp>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 36,
    booktabs: true,
    numbered-title: [`refreshLeaf(rank: uint32_t)`],
  )[
    + `leafNode = leafNode(spsc)                      `
    + `[old-rank, old-version] = leafNode->rank`
    + `[timestamp, ...] = enqueuers[rank].timestamp`
    + `CAS(&leafNode->rank, [old-rank, old-version], [timestamp == MAX ? DUMMY : rank, old-version + 1])`
  ],
) <ltqueue-refresh-leaf>

== Optimized LTQueue for distributed context
