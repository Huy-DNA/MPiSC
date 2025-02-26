#let title = [Modified LTQueue without Load-Link/Store-Conditional]

#set text(
  font: "Libertinus Serif",
  size: 11pt,
)
#set page(
  paper: "us-letter",
  header: align(right + horizon, title),
  numbering: "1",
)

#place(
  top + center,
  float: true,
  scope: "parent",
  clearance: 2em,
  text(17pt)[
    *#title*
  ],
)

#set par(justify: true)

#import "@preview/lovelace:0.3.0": *

= Original LTQueue

The original algorithm is given in @ltqueue by Prasad Jayanti and Srdjan Petrovic in 2005. LTQueue is a wait-free MPSC algorithm, with logarithmic-time for both enqueue and dequeue. The algorithm achieves good scalability by distributing the "global" queue over $n$ queues that are local to each enqueuer. This helps avoid contention on the global queue among the enqueuers and allows multiple enqueuers to succeed at the same time. Furthermore, each enqueue and dequeue is efficient: they are wait-free and guaranteed to complete in $theta(log n)$ where $n$ is the number of enqueuers. This is possible due to the novel tree structure proposed by the authors.

== Local queue algorithm

Each local queue in LTQueue is an SPSC that allows an enqueuer and a dequeuer to concurrently access. This suffices as only the enqueuer that the queue is local to and the one-and-only dequeuer ever access the local queue.

This section presents the SPSC data structure proposed in @ltqueue. Beside the usual `enqueue` and `dequeue` procedures, this SPSC also supports the `readFront` procedure, which allows the enqueuer and dequeuer to retrieve the first item in the SPSC. Notice that enqueuer and dequeuer each has its own `readFront` method.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t`
    + `node_t` =
      + *record*
        + `val`: `data_t`
        + `next`: *pointer to* `node_t`
      + *end*
]

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `First`: *pointer to* `node_t`
    + `Last`: *pointer to* `node_t`
    + `Announce`: *pointer to* `node_t`
    + `FreeLater`: *pointer to* `node_t`
    + `Help`: `data_t`
]

#pseudocode-list(line-numbering: none)[
  + *Initialization*
    + `First = Last = new Node()`
    + `FreeLater = new Node()`
]

The SPSC always has a dummy node at the end.

Enqueuer's procedures are given as follows.

#grid(
  columns: (1fr, 1fr),
  column-gutter: 30pt,
  figure(
    kind: "algorithm",
    supplement: [Procedure],
    pseudocode-list(
      booktabs: true,
      numbered-title: [`spsc_enqueue(v: data_t)`],
    )[
      + `newNode = new Node()`
      + `tmp = Last`
      + `tmp.val = v`
      + `tmp.next = newNode`
      + `Last = newNode`
    ],
  ),
  figure(
    kind: "algorithm",
    supplement: [Procedure],
    pseudocode-list(
      line-numbering: i => i + 5,
      booktabs: true,
      numbered-title: [`spsc_readFront`#sub[`e`]`()` returns `data_t`],
    )[
      + `tmp = First`
      + *if* `(tmp == Last)` *return* $bot$
      + `Announce = tmp`
      + *if* `(tmp != First)`
        + `retval = Help`
      + *else* `retval = tmp.val`
      + *return* `retval`
    ],
  ),
)

Dequeuer's procedures are given as follows.

#grid(
  columns: (1fr, 1fr),
  gutter: 30pt,
  figure(
    kind: "algorithm",
    supplement: [Procedure],
    pseudocode-list(
      line-numbering: i => i + 12,
      booktabs: true,
      numbered-title: [`spsc_dequeue()` returns `data_t`],
    )[
      + `tmp = First`
      + *if* `(tmp == Last)` *return* $bot$
      + `retval = tmp.val`
      + `Help = retval`
      + `First = tmp.next`
      + *if* `(tmp == Announce)`
        + `tmp' = FreeLater`
        + `FreeLater = tmp`
        + `free(tmp')`
      + *else* `free(tmp)`
      + *return* `retval`
    ],
  ),
  figure(
    kind: "algorithm",
    supplement: [Procedure],
    pseudocode-list(
      line-numbering: i => i + 23,
      booktabs: true,
      numbered-title: [`spsc_readFront`#sub[`d`]`()` returns `data_t`],
    )[
      + `tmp = First`
      + *if* `(tmp == Last)`
        + *return* $bot$
      + *return* `tmp.val`
    ],
  ),
)

The treatment of linearizability, wait-freedom and memory safety is given in the original paper @ltqueue. However, we can establish some intuition by looking at the procedures. For wait-freedom, each procedure doesn't loop and doesn't wait for any other procedures to be able to complete on its own, therefore, they are all wait-free. For memory safety, note that `spsc_enqueue` never accesses freed memory because the node pointed to by `Last` is never freed inside `spsc_dequeue`. `spsc_readFront`#sub[`e`] tries to read `First` (line 6) and announces it not to be deleted to the dequeuer (line 8), it then checks if the pointer it read is still `First` (line 9), if it is, then it's safe to dereference the pointer (line 11) because the dequeuer would take note not to free it (line 18), otherwise, it just returns `Help` (line 10), which is safely placed by the dequeuer (line 16). `spsc_dequeue` safely reclaims memory and does not leak memory (line 18-22). `spsc_readFront`#sub[`d`] is safe because there's only one dequeuer running at a time. For linearizability, the linearization point of `spsc_enqueue` is after line 5, `spsc_readFront`#sub[`e`] is right after line 8, `spsc_dequeue` is right after line 17 and `spsc_readFront`#sub[`d`] is right after line 25. Additionally, all the operations take constant time no matter the size of the queue.

== LTQueue algorithm

LTQueue's idea is to maintain a tree structure: Each leaf node corresponds to the SPSC local to each enqueuer. Every node in the local SPSC besides data, also contains a timestamp when it's enqueued into the SPSC. Each leaf node has one immediate parent containing the minimum timestamp of the local SPSC queue in that leaf. Every other internal node contains the minimum timestamp among its children's timestamps.

#figure(
  kind: "image",
  supplement: "Image",
  image("/assets/ltqueue-tree.png"),
  caption: [
    LTQueue's structure
  ],
)

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t`
    + `spsc_t` = The type of the local SPSC
    + `tree_t` = The type of the tree constructed by LTQueue
    + `node_t` = The node type of `tree_t`, containing a 64-bit timestamp value, packing a monotonic counter and the enqueuer's rank.
]

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `counter`: integer (`counter` supports LL and SC operations)
    + `Q`: *array* `[1..n]` *of* `spsc_t`
    + `T`: `tree_t`
]

#pseudocode-list(line-numbering: none)[
  + *Initialization*
    + `counter = 0`
]

#grid(
  columns: (1fr, 1fr),
  column-gutter: 30pt,
  figure(
    kind: "algorithm",
    supplement: [Procedure],
    pseudocode-list(
      booktabs: true,
      numbered-title: [`enqueue(rank: int, v: data_t)`],
    )[
      + `count = LL(counter)`
      + `SC(counter, count + 1)`
      + `timestamp = (count, rank)`
      + `spsc_enqueue(Q[rank], (v, timestamp))`
      + `propagate(Q[rank])`
    ],
  ),
  figure(
    kind: "algorithm",
    supplement: [Procedure],
    pseudocode-list(
      line-numbering: i => i + 5,
      booktabs: true,
      numbered-title: [`dequeue()` returns `data_t`],
    )[
      + `[count, rank] = read(root(T))`
      + *if* `(q == `$bot$`)` *return* $bot$
      + `ret = spsc_dequeue(Q[rank])`
      + `propagate(Q[rank])`
      + *return* `ret.val`
    ],
  ),
)

#grid(
  columns: (1fr, 1fr),
  column-gutter: 30pt,
  figure(
    kind: "algorithm",
    supplement: [Procedure],
    pseudocode-list(
      line-numbering: i => i + 10,
      booktabs: true,
      numbered-title: [`propagate(q:` *pointer to* `spsc_t)`],
    )[
      + `currentNode = q`
      + *repeat*
        + `currentNode = parent(currentNode)`
        + *if* $not$`refresh(currentNode)`
          + `refresh(currentNode)`
      + *until* `currentNode == root(T)`
    ],
  ),
  figure(
    kind: "algorithm",
    supplement: [Procedure],
    pseudocode-list(
      line-numbering: i => i + 16,
      booktabs: true,
      numbered-title: [`refresh(currentNode:` *pointer to* `node_t)`],
    )[
      + `LL(currentNode)`
      + *for* `childNode` in `children(q)`
        + *let* `minT` be the minimum timestamp for every `childNode`
      + `SC(currentNode, minT)`
    ],
  ),
)

Similarly, the proofs of LTQueue's linearizability, wait-freedom, memory-safety and logarithmic-time complexity of enqueue and dequeue operations are given in @ltqueue. One notable technique that allows LTQueue to be both correct and wait-free is the double-refresh trick during the propagation process on line 8-9. Because this propagation process is important in our modified version of LTQueue, we'll focus on the `propagate` and `refresh` procedures.

The idea behind the `propagate` procedure is simple: Each time an SPSC queue is modified (inserted/deleted), the timestamp of a leaf has changed so the timestamps of all nodes on the path from that leaf to the root can potentially change. Therefore, we have to propagate the change towards the root, starting from the leaf (line 11-16).

The `refresh` procedure is by itself simple: we access all child nodes to determine the minimum timestamp and try to set the current node's timestamp with the determined minimum timestamp using a pair of LL/SC. However, because LL/SC can fail, the procedure `refresh` can fail. The key to remedy this is to retry `refresh` on line 15 in case of the first `refresh`'s failure. Later, when we prove the correctness of the modified LTQueue, we'll provide a formal proof of why this works. Here, we'll just provide some visualizations for intuition.

#figure(
  kind: "image",
  supplement: "Image",
  image("/assets/double-refresh.png"),
  caption: [
    Even though two `refresh`s fails, the `currentNode`'s timestamp is still updated correctly
  ],
)

= Adaption of LTQueue without load-link/store-conditional

= Proof of correctness

== Linearizability

== Safe memory reclamation

== Wait-freedom

== Logarithm-time complexity for enqueues and dequeues

#bibliography("/bibliography.yml", title: [References])
