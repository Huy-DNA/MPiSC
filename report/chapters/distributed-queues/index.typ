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

In our description, we assume that each process in our program is assigned a unique number as an identifier, which is termed as its *rank*. The numbers are taken from the range of `[0, size - 1]`, with `size` being the number of processes in our program.

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

`void compare_and_swap_sync(remote<T> dest, T old_value, T new_value)`: Issue a synchronous compare-and-swap operation on the distributed variable `dest`. The operation atomically compares the current value of `dest` with `old_value`. If they are equal, the value of `dest` is replaced with `new_value`; otherwise, no change is made. The operation is guaranteed to be completed when the function returns, ensuring that the update (if any) is visible to all processes. The type `T` must be a data type with a size of `1`, `2`, `4`, or `8` bytes.

`void compare_and_swap_sync(remote<T*> dest, int index, T old_value, T new_value)`: Issue a synchronous compare-and-swap operation on the element at position `index` within the distributed array `dest` (where `dest` is a pointer to a remotely hosted array of type `T`). The operation atomically compares the current value of the element at `dest[index]` with `old_value`. If they are equal, the element at `dest[index]` is replaced with new_value; otherwise, no change is made. The operation is guaranteed to be completed when the function returns, ensuring that the update (if any) is visible to all processes. The type `T` must be a data type with a size of `1`, `2`, `4`, or `8`.

`void fetch_and_add_sync(remote<T> dest, T inc)`: Issue a synchronous fetch-and-add operation on the distributed variable `dest`. The operation atomically adds the value `inc` to the current value of `dest`, returning the original value of dest (before the addition) to the calling process. The update to `dest` is guaranteed to be completed and visible to all processes when the function returns. The type `T` must be an integral type with a size of `1`, `2`, `4`, or `8` bytes.

== A basis distributed SPSC <distributed-spsc>

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


== Modified LTQueue without LL/SC

The structure of our modified LTQueue is shown as in @modified-ltqueue-tree.

We differentiate between 2 types of nodes: *enqueuer nodes* (represented as the rectangular boxes at the bottom of @modified-ltqueue-tree) and normal *tree nodes* (represented as the circular boxes in @modified-ltqueue-tree).

Each enqueuer node corresponds to an enqueuer. Each time the local SPSC is enqueued with a value, the enqueuer timestamps the value using a distributed counter shared by all enqueuers. An enqueuer node stores the SPSC local to the corresponding enqueuer and a `min_timestamp` value which is the minimum timestamp inside the local SPSC.

Each tree node stores the rank of an enqueuer process. This rank corresponds to the enqueuer node with the minimum timestamp among the node's children's ranks. The tree node that's attached to an enqueuer node is called a *leaf node*, otherwise, it's called an *internal node*.

Note that if a local SPSC is empty, the `min_timestamp` variable of the corresponding enqueuer node is set to `MAX` and the corresponding leaf node's rank is set to a `DUMMY` rank.

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

Placement-wise:
- The *enqueuer nodes* are hosted at the corresponding *enqueuer*.
- All the *tree nodes* are hosted at the *dequeuer*.
- The distributed counter, which the enqueuers use to timestamp their enqueued value, is hosted at the *dequeuer*.

Below is the types utilized in our version of LTQueue.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of the data to be stored
    + `spsc_t` = The type of the SPSC, this is assumed to be the distributed SPSC in @distributed-spsc
    + `rank_t` = The type of the rank of an enqueuer process tagged with a unique timestamp (version) to avoid ABA problem
      + *struct*
        + `value`: `uint32_t`
        + `version`: `uint32_t`
      + *end*
    + `timestamp_t` = The type of the timestamp tagged with a unique timestamp (version) to avoid ABA problem
      + *struct*
        + `value`: `uint32_t`
        + `version`: `uint32_t`
      + *end*
    + `node_t` = The type of a tree node
      + *struct*
        + `rank`: `rank_t`
      + *end*
]

The shared variables in our LTQueue version are as followed.

Note that we have described a very specific and simple way to organize the tree nodes in LTQueue in a min-heap-like array structure hosted on the sole dequeuer. We will resume our description of the related tree-structure procedures `parent()` (@ltqueue-parent), `children()` (@ltqueue-children), `leafNodeIndex()` (@ltqueue-leaf-node-index) with this representation in mind. However, our algorithm doesn't strictly require this representation and can be subtituted with other more-optimized representations & distributed placements, as long as the similar tree-structure procedures are supported.

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `Counter`: `remote<uint64_t>`
      + A distributed counter shared by the enqueuers. Hosted at the dequeuer.
    + `Tree_size`: `uint64_t`
      + A read-only variable storing the number of tree nodes present in the LTQueue.
    + `Nodes`: `remote<node_t>`
      + An array with `Tree_size` entries storing all the tree nodes present in the LTQueue shared by all processes.
      + Hosted at the dequeuer.
      + This array is organized in a similar manner as a min-heap: At index `0` is the root node. For every index $i gt 0$, $floor((i - 1) / 2)$ is the index of the parent of node $i$. For every index $i gt 0$, $2i + 1$ and $2i + 2$ are the indices of the children of node $i$.
    + `Dequeuer_rank`: `uint32_t`
      + The rank of the dequeuer process.
    + `Enqueuers`: A read-only *array* `[0..size - 2]` of `remote<timestamp_t>`, with `size` being the number of processes.
      + The entry at index $i$ corresponds to the `Min_timestamp` distributed variable at the enqueuer with an order of $i$.
]

Similar to the fact that each process in our program is assigned a rank, each enqueuer process in our program is assigned an *order*. The following procedure computes an enqueuer's order based on its rank:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`uint32_t enqueuer_order(uint32_t enqueuer_rank)`],
  )[
    + *return* `enqueuer_rank > Dequeuer_rank ? enqueuer_rank - 1 : enqueuer_rank`
  ],
) <ltqueue-enqueuer-order>

This procedure is rather straightforward: Each enqueuer is assigned an order in the range `[0, size - 2]`, with `size` being the number of processes and the total ordering among the enqueuers based on their ranks is the same as the total ordering among the enqueuers based on their orders.

#pagebreak()

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Enqueuer-local variables*
      + `Enqueuer_count`: `uint64_t`
        + The number of enqueuers.
      + `Self_rank`: `uint32_t`
        + The rank of the current enqueuer process.
      + `Min_timestamp`: `remote<timestamp_t>`
      + `Spsc`: `spsc_t`
        + This SPSC is shared with the dequeuer.
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Dequeuer-local variables*
      + `Enqueuer_count`: `uint64_t`
        + The number of enqueuers.
  ]
]

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
      + Initialize `Enqueuers`, synchronizing each entry with the corresponding enqueuer.
  ]
]

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

Similarly, `children` returns all indices of the child tree nodes given the node with index `index`. These indices are based on the shared `Nodes` array. Based on how we organize the `Nodes` array, these indices can be either `index * 2 + 1` or `index * 2 + 2`.

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

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 12,
    booktabs: true,
    numbered-title: [`uint32_t leafNodeIndex(uint32_t enqueuer_rank)`],
  )[
    + *return* `Tree_size + enqueuer_order(enqueuer_rank)                         `
  ],
) <ltqueue-leaf-node-index>

`leafNodeIndex` returns the index of the leaf node that's logically attached to the enqueuer node with rank `enqueuer_rank` as in @modified-ltqueue-tree.

The followings are the enqueuer procedures:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 13,
    booktabs: true,
    numbered-title: [`bool enqueue(data_t value)`],
  )[
    + `count = FAA(Counter)                                                 `
    + `timestamp = timestamp_t {count, Self_rank}`
    + `spsc_enqueue(Spsc, (value, timestamp))`
    + `propagate`#sub(`e`)`()`
  ],
) <ltqueue-enqueue>

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
    + `current_node_index = leafNode(rank)`
    + *repeat*
      + `current_node_index = parent(current_node_index)`
      + *if* `(!refresh`#sub(`e`)`(current_node_index))`
        + `refresh`#sub(`e`)`(current_node_index)`
    + *until* `current_node_index == 0`
  ],
) <ltqueue-enqueue-propagate>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 27,
    booktabs: true,
    numbered-title: [`bool refreshTimestamp`#sub(`e`)`()`],
  )[
    + `{old-timestamp, old-version} = Min_timestamp                                 `
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

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 34,
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
      + `aread_sync(Enqueuers[child_rank], &child_timestamp)`
      + *if* `(child_timestamp < min_timestamp)`
        + `min_timestamp = child_timestamp`
        + `min_rank = child_rank`
    + *return* `compare_and_swap_sync(Nodes, current_node_index,
node_t {rank_t {old_rank, old_version}},
node_t {rank_t {min_rank, old_version + 1}})`
  ],
) <ltqueue-enqueue-refresh-node>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 50,
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

The followings are the dequeuer procedures:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`bool dequeue(data_t output)`],
  )[ ],
) <ltqueue-dequeue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`void propagate`#sub(`d`)`(uint32_t rank)`],
  )[ ],
) <ltqueue-dequeue-propagate>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`bool refreshTimestamp`#sub(`d`)`(uint32_t rank)`],
  )[ ],
) <ltqueue-dequeue-refresh-timestamp>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`bool refreshNode`#sub(`d`)`(uint32_t current_node_index)`],
  )[ ],
) <ltqueue-dequeue-refresh-node>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i,
    booktabs: true,
    numbered-title: [`bool refreshLeaf`#sub(`d`)`(uint32_t rank)`],
  )[ ],
) <ltqueue-dequeue-refresh-leaf>

== Optimized LTQueue for distributed context
