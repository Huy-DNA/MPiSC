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

    [Number of elements], [Unbounded], [Unbounded],
  ),
) <summary-of-distributed-mpscs>

In this section, we present our proposed distributed MPSCs in detail. Any other discussions about theoretical aspects of these algorithms such as linearizability, progress guarantee, time complexity are deferred to @theoretical-aspects[].

== A basis distributed SPSC

The two algorithms we propose here both utilize a distributed SPSC data structure, which we will present first. For implementation simplicity, we present a bounded SPSC, effectively make our proposed algorithms support only a bounded number of elements. However, one can trivially substitute another distributed unbounded SPSC to make our proposed algorithms support an unbounded number of elements, as long as this SPSC supports the same interface as ours.

#pagebreak()

#columns(2)[
  #pseudocode-list(line-numbering: none)[
    + *Types*
      + `data_t` = The type of data stored
      + `spsc_t` = The type of the local SPSC
        + *record*
          + `First`: `int`
          + `Last`: `int`
          + `Capacity`: `int`
          + `Data`: an array of `data_t` of capacity `Capacity`
        + *end*
  ]

  #colbreak()

  #pseudocode-list(line-numbering: none)[
    + *Shared variables*
      + `First`: index of the first undequeued entry
      + `Last`: index of the first unenqueued entry
  ]

  #pseudocode-list(line-numbering: none)[
    + *Initialization*
      + `First = Last = 0`
      + Set `Capacity` and allocate array.
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
    + *if* `(Last + 1 == First)                                                        `
      + *return* `false`
    + `Data[Last] = v`
    + `Last = (Last + 1) % Capacity`
    + *return* `true`
  ],
) <spsc-enqueue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 5,
    booktabs: true,
    numbered-title: [`spsc_dequeue()` *returns* `data_t`],
  )[
    + *if* `(First == Last)` *return* $bot$ `                                            `
    + `res = Data[First]`
    + `First = (First + 1) % Capacity`
    + *return* `res`
  ],
) <spsc-dequeue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 9,
    booktabs: true,
    numbered-title: [`spsc_readFront` *returns* `data_t`],
  )[
    + *if* `(First == Last)                                                    `
      + *return* $bot$
    + *return* `Data[First]`
  ],
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
