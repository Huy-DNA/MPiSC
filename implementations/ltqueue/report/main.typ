#let title = [
  Modified LTQueue without Load-Link/Store-Conditional]

#set document(
  author: "Đỗ Nguyễn An Huy",
  title: "Modified LTQueue without Load-Link/Store-Conditional",
)

#set text(
  font: "Libertinus Serif",
  size: 11pt,
)
#set page(
  paper: "us-letter",
  header: align(right + horizon, title),
  numbering: "1",
  columns: 2,
)

#place(
  auto,
  float: true,
  scope: "parent",
  clearance: 2em,
  text(18pt)[
    *#title*
  ],
)

#set par(justify: true)

#set heading(numbering: "1.")
#show heading.where(level: 3): set heading(numbering: none)

#show heading: name => [
  #name
  #v(10pt)
]

#set list(marker: ([•], [•]))

#show figure.where(kind: "algorithm"): set align(start)

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

= Original LTQueue

The original algorithm is given in @ltqueue by Prasad Jayanti and Srdjan Petrovic in 2005. LTQueue is a wait-free MPSC algorithm, with logarithmic-time complexity for both enqueue and dequeue operations. The algorithm achieves good scalability by distributing the "global" queue over $n$ queues that are local to each enqueuer. This helps avoid contention on the global queue among the enqueuers and allows multiple enqueuers to succeed at the same time. Furthermore, each enqueue and dequeue is efficient: they are wait-free and guaranteed to complete in $theta(log n)$ steps where $n$ is the number of enqueuers. This is possible due to the novel tree structure proposed by the authors.

== Local queue algorithm

Each local queue in LTQueue is an SPSC that allows an enqueuer and a dequeuer to concurrently access. Every enqueuer has one such local SPSC. Only the owner enqueuer and the dequeuer can access this local SPSC.

This section presents the SPSC data structure proposed in @ltqueue. Beside the usual `enqueue` and `dequeue` procedures, this SPSC also supports the `readFront` procedure, which allows the enqueuer and dequeuer to retrieve the first item in the SPSC. Notice that enqueuer and dequeuer each has its own `readFront` method.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of data stored
    + `node_t` = The type of the linked-list's nodes
      + *record*
        + `val`: `data_t`
        + `next`: *pointer to* `node_t`
      + *end*
]

#linebreak()

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

The enqueuer's procedures are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`spsc_enqueue(v: data_t)`],
  )[
    + `newNode = new Node()                    `
    + `tmp = Last`
    + `tmp.val = v`
    + `tmp.next = newNode`
    + `Last = newNode`
  ],
) <ltqueue-spsc-enqueue>
#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 5,
    booktabs: true,
    numbered-title: [`spsc_readFront`#sub[`e`]`()` *returns* `data_t`],
  )[
    + `tmp = First                                         `
    + *if* `(tmp == Last)` *return* $bot$
    + `Announce = tmp`
    + *if* `(tmp != First)`
      + `retval = Help`
    + *else* `retval = tmp.val`
    + *return* `retval`
  ],
) <ltqueue-spsc-enqueuer-readFront>

The dequeuer's procedures are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 12,
    booktabs: true,
    numbered-title: [`spsc_dequeue()` *returns* `data_t`],
  )[
    + `tmp = First                                      `
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
) <ltqueue-spsc-dequeue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 23,
    booktabs: true,
    numbered-title: [`spsc_readFront`#sub[`d`]`()` *returns* `data_t`],
  )[
    + `tmp = First                                  `
    + *if* `(tmp == Last)`
      + *return* $bot$
    + *return* `tmp.val`
  ],
) <ltqueue-spsc-dequeuer-readFront>

The treatment of linearizability, wait-freedom and memory safety is given in the original paper @ltqueue. However, we can establish some intuition by looking at the procedures.

For wait-freedom, each procedure doesn't loop and doesn't wait for any other procedures to be able to complete on its own, therefore, they are all wait-free.

For memory safety, note that `spsc_enqueue` never accesses freed memory because the node pointed to by `Last` is never freed inside `spsc_dequeue`. `spsc_readFront`#sub[`e`] tries to read `First` (line 6) and announces it not to be deleted to the dequeuer (line 8), it then checks if the pointer it read is still `First` (line 9), if it is, then it's safe to dereference the pointer (line 11) because the dequeuer would take note not to free it (line 18), otherwise, it returns `Help` (line 10), which is safely placed by the dequeuer (line 16). `spsc_dequeue` safely reclaims memory and does not leak memory (line 18-22). `spsc_readFront`#sub[`d`] is safe because there's only one dequeuer running at a time.

For linearizability, the linearization point of `spsc_enqueue` is after line 5, `spsc_readFront`#sub[`e`] is right after line 8, `spsc_dequeue` is right after line 17 and `spsc_readFront`#sub[`d`] is right after line 25. Additionally, all the operations take constant time no matter the size of the queue.

== LTQueue algorithm

LTQueue's idea is to maintain a tree structure as in @ltqueue-tree. Each enqueuer is represented by the local SPSC node at the bottom of the tree. Every SPSC node in the local queue contains data and a timestamp indicating when it's enqueued into the SPSC. For consistency in node structure, we consider the leaf nodes of the tree to be the ones that are attached to the local SPSC of each enqueuer. Every internal node contains the minimum timestamp among its children's timestamps.

#place(
  center + top,
  float: true,
  scope: "parent",
  [#figure(
      kind: "image",
      supplement: "Image",
      image("/assets/ltqueue-tree.png"),
      caption: [
        LTQueue's structure
      ],
    ) <ltqueue-tree>
  ],
)

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of the data to be stored in LTQueue
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

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`enqueue(rank: int, value: data_t)`],
  )[
    + `count = LL(counter)                        `
    + `SC(counter, count + 1)`
    + `timestamp = (count, rank)`
    + `spsc_enqueue(Q[rank], (value, timestamp))`
    + `propagate(Q[rank])`
  ],
)
#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 5,
    booktabs: true,
    numbered-title: [`dequeue()` *returns* `data_t`],
  )[
    + `[count, rank] = read(root(T))               `
    + *if* `(rank == `$bot$`)` *return* $bot$
    + `ret = spsc_dequeue(Q[rank])`
    + `propagate(Q[rank])`
    + *return* `ret.val`
  ],
)

The followings are the timestamp propagation procedures.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 10,
    booktabs: true,
    numbered-title: [`propagate(spsc: spsc_t)`],
  )[
    + *if* $not$`refreshLeaf(spsc)                       `
      + `refreshLeaf(spsc)`
    + `currentNode = leafNode(spsc)`
    + *repeat*
      + `currentNode = parent(currentNode)`
      + *if* $not$`refresh(currentNode)`
        + `refresh(currentNode)`
    + *until* `currentNode == root(T)`
  ],
)

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 18,
    booktabs: true,
    numbered-title: [`refresh(currentNode:` *pointer* to `node_t)`],
  )[
    + `LL(currentNode)`
    + *for* `childNode` in `children(currentNode)`
      + *let* `minT` be the minimum timestamp for every `childNode`
    + `SC(currentNode, minT)`
  ],
)

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 22,
    booktabs: true,
    numbered-title: [`refreshLeaf(spsc: spsc_t)`],
  )[
    + `leafNode = leafNode(spsc)                      `
    + `LL(leafNode)`
    + `SC(leafNode, spsc_readFront(spsc))`
  ],
)

Note that compare to the original paper @ltqueue, we have make some trivial modification on line 11-12 to handle the leaf node case, which was left unspecified in the original algorithm. In many ways, this modification is in the same light with the mechanism the algorithm is already using, so intuitively, it should not affect the algorithm's correctness or wait-freedom. Note that on line 25 of `refreshLeaf`, we omit which version of `spsc_readFront` it's calling, simply assume that the dequeuer and the enqueuer should call their corresponding version of `spsc_readFront`.


Similarly, the proofs of LTQueue's linearizability, wait-freedom, memory-safety and logarithmic-time complexity of enqueue and dequeue operations are given in @ltqueue. One notable technique that allows LTQueue to be both correct and wait-free is the double-refresh trick during the propagation process on line 16-17.

The idea behind the `propagate` procedure is simple: Each time an SPSC queue is modified (inserted/deleted), the timestamp of a leaf has changed so the timestamps of all nodes on the path from that leaf to the root can potentially change. Therefore, we have to propagate the change towards the root, starting from the leaf (line 11-18).

The `refresh` procedure is by itself simple: we access all child nodes to determine the minimum timestamp in each child's subtree and try to set the current node's timestamp with the minimum timestamp using a pair of LL/SC. However, LL/SC can not always succeed so the current node's timestamp may not be updated by `refresh` at all. The key to fix this is to retry `refresh` on line 17 in case of the first `refresh`'s failure. Later, when we prove the correctness of the modified LTQueue, we provide a formal proof of why this works. Here, for intuition, we visualize in @double-refresh the case where both `refresh` fails but correctness is still ensures.


#place(
  center + bottom,
  float: true,
  scope: "parent",
  [#figure(
      kind: "image",
      supplement: "Image",
      image("/assets/double-refresh.png", height: 200pt, fit: "stretch"),
      caption: [
        Even though two `refresh`s fails, the `currentNode`'s timestamp is still updated correctly
      ],
    ) <double-refresh>],
)

= Adaption of LTQueue without load-link/store-conditional

The SPSC data structure in the original LTQueue is kept in tact so one may refer to @ltqueue-spsc-enqueue, @ltqueue-spsc-enqueuer-readFront, @ltqueue-spsc-dequeue, @ltqueue-spsc-dequeuer-readFront for the supported SPSC procedures.

The followings are the rewritten LTQueue's algorithm without LL/SC.

#pagebreak()

The structure of LTQueue is modified as in @modified-ltqueue-tree. At the bottom *enqueuer nodes* (represented by the type `enqueuer_t`), besides the local SPSC, the minimum-timestamp among the elements in the SPSC is also stored. The *internal nodes* no longer store a timestamp but a rank of an enqueuer. This rank corresponds to the enqueuer with the minimum timestamp among the node's children's ranks. Note that if a local SPSC is empty, the minimum-timestamp of the corresponding enqueuer node is set to `MAX` and the corresponding leaf node's rank is set to a `DUMMY` rank.

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


#place(
  center + bottom,
  float: true,
  scope: "parent",
  [#figure(
      kind: "image",
      supplement: "Image",
      image("/assets/modified-ltqueue.png"),
      caption: [
        Modified LTQueue's structure
      ],
    ) <modified-ltqueue-tree>
  ],
)

#pseudocode-list(line-numbering: none)[
  + *Initialization*
    + `counter = 0`
    + construct the tree structure and set `root` to the root node
    + initialize every node in the tree to contain `DUMMY` rank and version `0`
    + initialize every enqueuer's `timestamp` to `MAX` and version `0`
]

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`enqueue(rank: int, value: data_t)`],
  )[
    + `timestamp = FAA(counter)                        `
    + `spsc_enqueue(enqueuers[rank].spsc, (value, timestamp))`
    + `propagate(rank)`
  ],
) <ltqueue-enqueue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 3,
    booktabs: true,
    numbered-title: [`dequeue()` *returns* `data_t`],
  )[
    + `[rank, version] = root->rank               `
    + *if* `(rank == DUMMY)` *return* $bot$
    + `ret = spsc_dequeue(enqueuers[rank].spsc)`
    + `propagate(rank)`
    + *return* `ret.val`
  ],
) <ltqueue-dequeue>

We omit the description of procedures `parent`, `leafNode`, `children`, leaving how the tree is constructed and children-parent relationship is determined to the implementor. The tree structure used by LTQueue is read-only so a wait-free implementation of these procedures is trivial.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 8,
    booktabs: true,
    numbered-title: [`propagate(rank: uint32_t)`],
  )[
    + *if* $not$`refreshTimestamp(rank)                 `
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
    line-numbering: i => i + 18,
    booktabs: true,
    numbered-title: [`refresh(currentNode:` *pointer* to `node_t)`],
  )[
    + `[old-rank, old-version] = currentNode->rank`
    + `min-rank = DUMMY`
    + `min-timestamp = MAX`
    + *for* `childNode` in `children(currentNode)`
      + `[child-rank, ...] = childNode->rank`
      + *if* `(child-rank == DUMMY)` *continue*
      + `child-timestamp = enqueuers[child-rank].min-timestamp`
      + *if* `(child-timestamp < min-timestamp)`
        + `min-timestamp = child-timestamp`
        + `min-rank = child-rank`
    + *return* `CAS(&currentNode->rank, [old-rank, old-version], [min-rank, old-version + 1])`
  ],
) <ltqueue-refresh>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 29,
    booktabs: true,
    numbered-title: [`refreshTimestamp(rank: uint32_t)`],
  )[
    + `[old-timestamp, old-version] = enqueuers[rank].timestamp`
    + `front = spsc_readFront(enqueuers[rank].spsc)`
    + *if* `(front == `$bot$`)`
      + *return* `CAS(&enqueuers[rank].timestamp, [old-timestamp, old-version], [MAX, old-version + 1])`
    + *else*
      + *return* `CAS(&enqueuers[rank].timestamp, [old-timestamp, old-version], [front.timestamp, old-version + 1])`
  ],
) <ltqueue-refresh-timestamp>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 35,
    booktabs: true,
    numbered-title: [`refreshLeaf(rank: uint32_t)`],
  )[
    + `leafNode = leafNode(spsc)                      `
    + `[old-rank, old-version] = leafNode->rank`
    + `[timestamp, ...] = enqueuers[rank].timestamp`
    + *return* `CAS(&leafNode->rank, [old-rank, old-version], [timestamp == MAX ? DUMMY : rank, old-version + 1])`
  ],
) <ltqueue-refresh-leaf>

Notice that we omit which version of `spsc_readFront` we're calling on line 32, simply assuming that the producer and each enqueuer are calling their respective version.

= Proof of correctness

This section proves that the algorithm given in the last section is linearizable, memory-safe and wait-free.

== Linearizability

Within the next two sections, we formalize what it means for an MPSC to be linearizable.

=== Definition of linearizability

The following discussion of linearizability is based on @art-of-multiprocessor-programming by Herlihy and Shavit.

For a concurrent object `S`, we can call some methods on `S` concurrently. A method call on the object `S` is said to have an *invocation event* when it starts and a *response event* when it ends.

#definition[An *invocation event* is a triple $(S, t, a r g s)$, where $S$ is the object the method is invoked on, $t$ is the timestamp of when the event happens and $a r g s$ is the arguments passed to the method call.]

#definition[A *response event* is a triple $(S, t, r e s)$, where $S$ is the object the method is invoked on, $t$ is the timestamp of when the event happens and $r e s$ is the results of the method call.]

#definition[A *method call* is a tuple of $(i, r)$ where $i$ is an invocation event and $r$ is a response event or the special value $bot$ indicating that its response event hasn't happened yet. A well-formed *method call* should have a reponse event with a larger timestamp than its invocation event or the response event hasn't happened yet.]

#definition[A *method call* is *pending* if its invocation event is $bot$.]

#definition[A *history* is a set of well-formed *method calls*.]

#definition[An extension of *history* $H$ is a *history* $H'$ such that any pending method call is given a response event.]

We can define a *strict partial order* on the set of well-formed method calls:

#definition[$->$ is a relation on the set of well-formed method calls. With two method calls $X$ and $Y$, we have $X -> Y <=>$ $X$'s response event is not $bot$ and its response timestamp is not greater than $Y$'s invocation timestamp.]

#definition[Given a *history* H, $->$#sub($H$) is a relation on $H$ such that for two method calls $X$ and $Y$ in $H$, $X ->$#sub($H$)$ Y <=> X -> Y$.]

#definition[A *sequential history* $H$ is a *history* such that $->$#sub($H$) is a total order on $H$.]

Now that we have formalized the way to describe the order of events via *histories*, we can now formalize the mechanism to determine if a *history* is valid. The easier case is for a *sequential history*:

#definition[For a concurrent object $S$, a *sequential specification* of $S$ is a function that either returns `true` (valid) or `false` (invalid) for a *sequential history* $H$.]

The harder case is handled via the notion of *linearizable*:

#definition[A history $H$ on a concurrent object $S$ is *linearizable* if it has an extension $H'$ and there exists a _sequential history_ $H_S$ such that:
  1. The *sequential specification* of $S$ accepts $H_S$.
  2. There exists a one-to-one mapping $M$ of a method call $(i, r) in H'$ to a method call $(i_S, r_S) in H_S$ with the properties that:
    - $i$ must be the same as $i_S$ except for the timestamp.
    - $r$ must be the same $r_S$ except for the timestamp or $r$.
  3. For any two method calls $X$ and $Y$ in $H'$, #linebreak() $X ->$#sub($H'$)$Y => $ $M(X) ->$#sub($H_S$)$M(Y)$.
]

We consider a history to be valid if it's linearizable.

=== Definition of linearizable MPSC

An MPSC supports 2 *methods*:
- `enqueue` which accepts a value and returns nothing
- `dequeue` which doesn't accept anything and returns a value

An MPSC has the same *sequential specification* as a FIFO:
- `dequeue` returns values in the same order as they was `enqueue`d.
- An `enqueue` can only be `dequeue`d once.
- An item can only be `dequeue`d after it's `enqueue`d.
- If the queue is empty, `dequeue` returns nothing.

An MPSC places a special constraint on *the set of histories* it can produce: Any history $H$ must not have overlapping `dequeue` method calls.

#definition[An MPSC is *linearizable* if and only if any history produced from the MPSC that does not have overlapping `dequeue` method calls is _linearizable_ according to the _FIFO sequential specification_.]

=== Proof of linearizability

#definition[An `enqueue` operation $e$ is said to *match* a `dequeue` operation $d$ if $d$ returns a timestamp that $e$ enqueues. Similarly, $d$ is said to *match* $e$. In this case, both $e$ and $d$ are said to be *matched*.]

#definition[An `enqueue` operation $e$ is said to be *unmatched* if no `dequeue` operation *matches* it.]

#definition[A `dequeue` operation $d$ is said to be *unmatched* if no `enqueue` operation *matches* it, in other word, $d$ returns $bot$.]

#theorem[Only the dequeuer and one enqueuer can operate on an enqueuer node.]

#proof[This is trivial.]

We immediately obtain the following result.

#corollary[Only one `dequeue` operation and one `enqueue` operation can operate concurrently on an enqueuer node.] <ltqueue-one-dequeue-one-enqueue-corollary>

#proof[This is trivial.]

#theorem[The SPSC at an enqueuer node contains items with increasing timestamps.] <ltqueue-increasing-timestamp-theorem>

#proof[
  Each `enqueue` would `FAA` the shared counter (line 1 in @ltqueue-enqueue) and enqueue into the local SPSC an item with the timestamp obtained from the counter. Applying @ltqueue-one-dequeue-one-enqueue-corollary, we know that items are enqueued one at a time into the SPSC. Therefore, later items are enqueued by later `enqueue`s, which obtain increasing values by `FAA`-ing the shared counter. The theorem holds.
]

#definition[For a tree node $n$, the enqueuer rank stored in $n$ at time $t$ is denoted as $r a n k(n, t)$.]

#definition[For an `enqueue` or a `dequeue` $op$, the rank of the enqueuer it affects is denoted as $r a n k(op)$.]

#definition[For an enqueuer whose rank is $r$, the `min-timestamp` value stored in its enqueuer node at time $t$ is denoted as $m i n \- t s(r, t)$. If $r$ is `DUMMY`, $m i n \- t s(r, t)$ is `MAX`.]

#definition[For an enqueuer with rank $r$, the minimum timestamp among the elements between `First` and `Last` in the local SPSC at time $t$ is denoted as $m i n \- s p s c \- t s(r, t)$. If $r$ is dummy, $m i n \- s p s c \- t s(r, t)$ is `MAX`.]

#definition[For an `enqueue` or a `dequeue` $op$, the set of nodes that it calls `refresh` or `refreshLeaf` on is denoted as $p a t h(op)$.]

#definition[For an `enqueue` or a `dequeue`, *timestamp-refresh phase* refer to its execution of line 9-10 in `propagate` (@ltqueue-propagate).]

#definition[For an `enqueue` or a `dequeue` $op$, and a node $n in p a t h(op)$, *node-$n$-refresh phase* refer to its execution of line 11-12 (if $n$ is a leaf node) or line 16-17 (if $n$ is a non-leaf node) to refresh $n$'s rank in `propagate` (@ltqueue-propagate).]

#definition[`refreshTimestamp` is said to start its *CAS-sequence* if it finishes line 30 in @ltqueue-refresh-timestamp. `refreshTimestamp` is said to end its *CAS-sequence* if it finishes line 33 or line 35 in @ltqueue-refresh-timestamp.]

#definition[`refresh` is said to start its *CAS-sequence* if it finishes line 19 in @ltqueue-refresh. `refresh` is said to end its *CAS-sequence* if it finishes line 29 in @ltqueue-refresh.]

#definition[`refreshLeaf` is said to start its *CAS-sequence* if it finishes line 37 in @ltqueue-refresh-leaf. `refreshLeaf` is said to end its *CAS-sequence* if it finishes line 39 in @ltqueue-refresh-leaf.]

#theorem[For an `enqueue` or a `dequeue` $op$, if $op$ modifies an enqueuer node and this enqueuer node is attached to a leaf node $l$, then $p a t h(op)$ is the set of nodes lying on the path from $l$ to the root node.]

#proof[This is trivial considering how `propagate` (@ltqueue-propagate) works.]

#theorem[For any time $t$ and a node $n$, $r a n k(n, t)$ can only be `DUMMY` or the rank of one of the enqueuer nodes in the subtree rooted at $n$.] <ltqueue-possible-ranks-theorem>

#proof[This is trivial considering how `refresh` and `refreshLeaf` works.]

#theorem[If an `enqueue` or a `dequeue` $op$ begins its *timestamp-refresh phase* at $t_0$ and finishes at time $t_1$, there's always at least one successful `refreshTimestamp` on $r a n k(op)$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$.] <ltqueue-refresh-timestamp-theorem>

#proof[
  If one of the two `refreshTimestamp`s succeeds, then the theorem obviously holds.

  Consider the case where both fail.

  The first `refreshTimestamp` fails because there's another `refreshTimestamp` ending its *CAS-sequence* successfully after $t_0$ but before the end of the first `refreshTimestamp`'s *CAS-sequence*.

  The second `refreshTimestamp` fails because there's another `refreshTimestamp` ending its *CAS-sequence* successfully after $t_0$ but before the end of the second `refreshTimestamp`'s *CAS-sequence*. This another `refreshTimestamp` must start its *CAS-sequence* after the end of the first successful `refreshTimestamp`, else it overlaps with the *CAS-sequence* of the first successful `refreshTimestamp` but successful *CAS-sequences* cannot overlap. In other words, this another `refreshTimestamp` starts and successfully ends its *CAS-sequence* between $t_0$ and $t_1$.

  We have proved the theorem.
]

#theorem[If an `enqueue` or a `dequeue` begins its *node-$n$-refresh phase* at $t_0$ and finishes at $t_1$, there's always at least one successful `refresh` or `refreshLeaf` on $n$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$.] <ltqueue-refresh-node-theorem>

#proof[This is similar to the above proof.]

#theorem[For any node $n$, $m i n \- t s(r a n k(n, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_0, t_1]$ if within $t_0$ and $t_1$, any `dequeue` $d$ where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*.] <ltqueue-monotonic-theorem>

#proof[
  We have the assumption that within $t_0$ and $t_1$, all `dequeue` where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*. Notice that if $n$ satisfies this assumption, any child of $n$ also satisfies this assumption.

  We will prove a stronger version of this theorem: Given a node $n$, time $t_0$ and $t_1$ such that within $[t_0, t_1]$, any `dequeue` $d$ where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*. Consider the last `dequeue`'s *node-$n$-refresh phase* before $t_0$ (there maybe none). Take $t_s (n)$ and $t_e (n)$ to be the starting and ending time of the CAS-sequence of the last successful *$n$-refresh call* during this phase, or if there is none, $t_s (n) = t_e (n) = 0$. Then, $m i n \- t s(r a n k(n, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_e (n), t_1]$.

  Consider any enqueuer node of rank $r$ that's attached to a satisfied leaf node. For any $n'$ that is a descendant of $n$, during $t_s (n')$ and $t_1$, there's no call to `spsc_dequeue`. Because:
  - If an `spsc_dequeue` starts between $t_0$ and $t_1$, the `dequeue` that calls it hasn't finished its *node-$n'$-refresh phase*.
  - If an `spsc_dequeue` starts between $t_s (n')$ and $t_0$, then a `dequeue`'s *node-$n'$-refresh phase* must start after $t_s (n')$ and before $t_0$, but this violates our assumption of $t_s (n')$.
  Therefore, there can only be calls to `spsc_enqueue` during $t_s (n')$ and $t_1$. Thus, $m i n \- s p s c \- t s(r, t_x)$ can only decrease from `MAX` to some timestamp and remain constant for $t_x in [t_s (n'), t_1]$. $(1)$

  Similarly, there can be no `dequeue` that hasn't finished its *timestamp-refresh phase* during $t_s (n')$ and $t_1$. Therefore, $m i n \- t s (r, t_x)$ can only decrease from `MAX` to some timestamp and remain constant for $t_x in [t_s (n'), t_1]$. $(2)$

  Consider any satisfied leaf node $n_0$. There can be no `dequeue` that hasn't finished its *node-$n_0$-refresh phase* during $t_e (n_0)$ and $t_1$. Therefore, any successful `refreshLeaf` on $n_0$ during $[t_e (n_0), t_1]$ must be called by an `enqueue`. Because there's no `spsc_dequeue`, this `refreshLeaf` can only set $r a n k(n_0, t_x)$ from `DUMMY` to $r$ and this remain $r$ until $t_1$, which is the rank of the enqueuer node it's attached to. Therefore, combining with $(1)$, $m i n \- t s(r a n k(n_0, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_e (n_0), t_1]$. $(3)$

  Consider any satisfied non-leaf node $n'$ that is a descendant of $n$. Suppose during $[t_e (n'), t_1]$, we have a sequence of successful *$n'$-refresh calls* that start their CAS-sequences at $t_(s t a r t \- 0) lt t_(s t a r t \- 1) lt t_(s t a r t \- 2) lt ... lt t_(s t a r t \- k)$ and end them at $t_(e n d \- 0) lt t_(e n d \- 1) lt t_(e n d\- 2) lt ... lt t_(e n d \- k)$. By definition, $t_(e n d \- 0) = t_e (n')$ and $t_(s t a r t \- 0) = t_s (n')$. We can prove that $t_(e n d \- i) < t_(s t a r t \- (i+1))$ because successful CAS-sequences cannot overlap.

  Due to how `refresh` is defined, for any $k gt.eq i gt.eq 1$:
  - Suppose $t_(r a n k\-i)(c)$ is the time `refresh` reads the rank stored in the child node $c$, so $t_(s t a r t \- i) lt.eq t_(r a n k\-i)(c) lt.eq t_(e n d \- i)$.
  - Suppose $t_(t s\-i)(c)$ is the time `refresh` reads the timestamp stored in the enqueuer with the rank read previously, so $t_(s t a r t \- i) lt.eq t_(t s\-i)(c) lt.eq t_(e n d \- i)$.
  - There exists a child $c_i$ such that $r a n k(n', t_(e n d \- i)) = r a n k(c_i, t_(r a n k\-i)(c_i))$. $(4)$
  - For every child $c$ of $n'$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-i)(c)), t_(t s\-i)(c))$. $(5)$

  Suppose the stronger theorem already holds for every child $c$ of $n'$. $(6)$

  For any $i gt.eq 1$, we have $t_e (c) lt.eq t_s (n') lt.eq t_(s t a r t \-(i-1)) lt.eq t_(r a n k\-(i-1))(c) lt.eq t_(e n d \-(i-1)) lt.eq t_(s t a r t \-i) lt.eq t_(r a n k \- i)(c) lt.eq t_1$. Combining with $(5)$, $(6)$, we have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-i)(c)), t_(t s\-i)(c))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-(i-1))(c)), t_(t s\-i)(c))$.

  Choose $c = c_(i-1)$ as in $(4)$. We have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c_(i-1), t_(r a n k\-(i-1))(c_(i-1))),$$ t_(t s\-i)(c_(i-1)))$ #linebreak() $= m i n\- t s(r a n k(n', t_(e n d \- (i-1))), t_(t s \-i)(c_(i-1))$.

  Because $t_(t s \-i)(c_i) lt.eq t_(e n d \- i)$ and $t_(t s \-i)(c_(i-1)) gt.eq t_(e n d \- (i-1))$ and $(2)$, we have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(e n d\-i))$ #linebreak() $lt.eq m i n \- t s (r a n k(n', t_(e n d \- (i-1))), t_(e n d \- (i-1)))$. $(*)$

  $r a n k(n', t_x)$ can only change after each successful `refresh`, therefore, the sequence of its value is $r a n k(n', t_(e n d \- 0))$, $r a n k(n', t_(e n d \- 1))$, ..., $r a n k(n', t_(e n d \- k))$. $(**)$

  Note that if `refresh` observes that an enqueuer has a `min-timestamp` of `MAX`, it would never try to CAS $n'$'s rank to the rank of that enqueuer (line 21 and line 26 of @ltqueue-refresh). So, if `refresh` actually set the rank of $n'$ to some non-`DUMMY` value, the corresponding enqueuer must actually has a non-`MAX` `min-timestamp` _at some point_. Due to $(2)$, this is constant up until $t_1$. Therefore, $m i n \- t s(r a n k(n', t_(e n d \- i)), t))$ is constant for any $t gt.eq t_(e n d \- i)$ and $k gt.eq i gt.eq 1$. $m i n \- t s(r a n k(n', t_(e n d \- 0)), t))$ is constant for any $t gt.eq t_(e n d \- 0)$ if there's a `refresh` before $t_0$. If there's no `refresh` before $t_0$, it is constant `MAX`. So, $m i n \- t s(r a n k(n', t_(e n d \- i)), t))$ is constant for any $t gt.eq t_(e n d \- i)$ and $k gt.eq i gt.eq 0$. $(***)$

  Combining $(*)$, $(**)$, $(***)$, we obtain the stronger version of the theorem.
]

#theorem[If an `enqueue` $e$ obtains a timestamp $c$ and finishes at time $t_0$ and is still *unmatched* at time $t_1$, then for any subrange $T$ of $[t_0, t_1]$ that does not overlap with a `dequeue`, $m i n \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.] <ltqueue-unmatched-enqueue-theorem>

#proof[
  We will prove a stronger version of this theorem: Suppose an `enqueue` $e$ obtains a timestamp $c$ and finishes at time $t_0$ and is still *unmatched* at time $t_1$. For every $n_i in p a t h(e)$, $n_0$ is the leaf node and $n_i$ is the parent of $n_(i-1)$, $i gt.eq 1$. If $e$ starts and finishes its *node-$n_i$-refresh phase* at $t_(s t a r t\-i)$ and $t_(e n d\-i)$ then for any subrange $T$ of $[t_(e n d\-i), t_1]$ that does not overlap with a `dequeue` $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node $n_i$ refresh phase*, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  If $t_1 lt t_0$ then the theorem holds.

  Take $r_e$ to be the rank of the enqueuer that performs $e$.

  Suppose $e$ enqueues an item with the timestamp $c$ into the local SPSC at time $t_(e n q u e u e)$. Because it's still unmatched up until $t_1$, $c$ is always in the local SPSC during $t_(e n q u e u e)$ to $t_1$. Therefore, $m i n \- s p s c \- t s(r_e, t) lt.eq c$ for any $t in [t_(e n q u e u e), t_1]$. $(1)$

  Suppose $e$ finishes its *timestamp refresh phase* at $t_(r\-t s)$. Because $t_(r\-t s) gt.eq t_(e n q u e u e)$, due to $(1)$, $m i n \- t s(r_e, t) lt.eq c$ for every $t in [t_(r\-t s),t_1]$. $(2)$

  Consider the leaf node $n_0 in p a t h (e)$. Due to $(2)$, $r a n k(n_0, t)$ is always $r_e$ for any $t in [t_(e n d\-0), t_1]$. Also due to $(2)$, $m i n \- t s(r a n k(n_0, t_r), t_s) lt.eq c$ for any $t_r, t_s in [t_(e n d\-0), t_1]$.

  Consider any non-leaf node $n_i in p a t h(e)$. We can extend any subrange $T$ to the left until we either:
  - Reach a `dequeue` $d$ such that $n_i in p a t h (d)$ and $d$ has just finished its *node-$n_i$-refresh phase*.
  - Reach $t_(e n d \- i)$.
  Consider one such subrange $T_i$.

  Notice that $T_i$ always starts right after a *node-$n_i$-refresh phase*. Due to @ltqueue-refresh-node-theorem, there's always at least one successful `refresh` in this *node-$n_i$-refresh phase*.

  Suppose the stronger version of the theorem already holds for $n_(i-1)$. That is, if $e$ starts and finishes its *node-$n_(i-1)$-refresh phase* at $t_(s t a r t\-(i-1))$ and $t_(e n d\-(i-1))$ then for any subrange $T$ of $[t_(e n d\-(i-1)), t_1]$ that does not overlap with a `dequeue` $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node $n_(i-1)$ refresh phase*, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  Extend $T_i$ to the left until we either:
  - Reach a `dequeue` $d$ such that $n_i in p a t h (d)$ and $d$ has just finished its *node-$n_(i-1)$-refresh phase*.
  - Reach $t_(e n d \- (i-1))$.
  Take the resulting range to be $T_(i-1)$. Obviously, $T_i subset.eq T_(i-1)$.

  $T_(i-1)$ satisifies both criteria:
  - It's a subrange of $[t_(e n d\-(i-1)), t_1]$.
  - It does not overlap with a `dequeue` $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node-$n_(i-1)$-refresh phase*.
  Therefore, $m i n \- t s(r a n k(n_(i-1), t_r), t_s) lt.eq c$ for any $t_r, t_s in T_(i-1)$.

  Consider the last successful `refresh` on $n_i$ ending not after $T_i$, take $t_s'$ and $t_e'$ to be the start and end time of this `refresh`'s CAS-sequence. Because right at the start of $T_i$, a *node-$n_i$-refresh phase* just ends, this `refresh` must be within this *node-$n_i$-refresh phase*. $(4)$

  This `refresh`'s CAS-sequence must be within $T_(i-1)$. This is because right at the start of $T_(i-1)$, a *node-$n_(i-1)$-refresh phase* just ends and $T_(i-1) supset.eq T_i$, $T_(i-1)$ must cover the *node-$n_i$-refresh phase* whose end $T_i$ starts from. Combining with $(4)$, $t_s' in T_(i-1)$ and $t_e' in T_i$. $(5)$

  Due to how `refresh` is defined and the fact that $n_(i-1)$ is a child of $n_i$:
  - $t_(r a n k)$ is the time `refresh` reads the rank stored in $n_(i-1)$, so that $t_s' lt.eq t_(r a n k) lt.eq t_e'$. Combining with $(5)$, $t_(r a n k) in T_(i-1)$.
  - $t_(t s)$ is the time `refresh` reads the timestamp from that rank $t_s' lt.eq t_(t s) lt.eq t_e'$. Combining with $(5)$, $t_(t s) in T_(i-1)$.
  - There exists a time $t'$, $t_s' lt.eq t' lt.eq t_e'$, #linebreak() $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq m i n \- t s (r a n k(n_(i-1), t_(r a n k)), t_(t s))$. $(6)$

  From $(6)$ and the fact that $t_(r a n k) in T_(i-1)$ and $t_(t s) in T_(i-1)$, $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq c$.

  There shall be no `spsc_dequeue` starting within $t_s'$ till the end of $T_i$ because:
  - If there's an `spsc_dequeue` starting within $T_i$, then $T_i$'s assumption is violated.
  - If there's an `spsc_dequeue` starting after $t_s'$ but before $T_i$, its `dequeue` must finish its *node-$n_i$-refresh phase* after $t_s'$ and before $T_i$. However, then $t_e'$ is no longer the end of the last successful `refresh` on $n_i$ not after $T_i$.
  Because there's no `spsc_dequeue` starting in this timespan, $m i n \- t s(r a n k(n_i, t_e'), t_e') lt.eq m i n \- t s(r a n k(n_i, t_e'), t') lt.eq c$.

  If there's no `dequeue` between $t_e'$ and the end of $T_i$ whose *node-$n_i$-refresh phase* hasn't finished, then by @ltqueue-monotonic-theorem, $m i n \- t s(r a n k(n_i, t_r), t_s)$ is monotonically decreasing for any $t_r$, $t_s$ starting from $t_e'$ till the end of $T_i$. Therefore, $m i n \- t s (r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_i$.

  Suppose there's a `dequeue` whose *node-$n_i$-refresh phase* is in progress some time between $t_e'$ and the end of $T_i$. By definition, this `dequeue` must finish it before $T_i$. Because $t_e'$ is the time of the last successful `refresh` on $n_i$ before $T_i$, $t_e'$ must be within the *node-$n_i$-refresh phase* of this `dequeue` and there should be no `dequeue` after that. By the way $t_e'$ is defined, technically, this `dequeue` has finished its *node-$n_i$-refresh phase* right at $t_e'$. Therefore, similarly, we can apply @ltqueue-monotonic-theorem, $m i n \- t s (r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_i$.

  By induction, we have proved the stronger version of the theorem.
]

#corollary[If an `enqueue` $e$ obtains a timestamp $c$ and finishes at time $t_0$ and is still *unmatched* at time $t_1$, then for any subrange $T$ of $[t_0, t_1]$ that does not overlap with a `dequeue`, $m i n \- s p s c \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.] <ltqueue-unmatched-enqueue-corollary>

#proof[
  Call $t_(s t a r t)$ and $t_(e n d)$ to be the start and end time of $T$.

  Applying @ltqueue-unmatched-enqueue-theorem, we have that $m i n \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  Fix $t_r$ so that $r a n k(r o o t, t_r) = r$. We have that $m i n \- t s(r, t) lt.eq c$ for any $t in T$.

  $m i n \- t s(r, t)$ can only change due to a successful `refreshTimestamp` on the enqueuer node with rank $r$. Consider the last successful `refreshTimestamp` on the enqueuer node with rank $r$ not after $T$. Suppose that `refreshTimestamp` reads out the minimum timestamp of the local SPSC at $t' lt.eq t_(s t a r t)$.

  Therefore, $m i n \- t s(r, t_(s t a r t)) = m i n \- s p s c \- t s(r, t') lt.eq c$.

  We will prove that after $t'$ until $t_(e n d)$, there's no `spsc_dequeue` on $r$ running.

  Suppose the contrary, then this `spsc_dequeue` must be part of a `dequeue`. By definition, this `dequeue` must start and end before $t_(s t a r t)$, else it violates the assumption of $T$. If this `spsc_dequeue` starts after $t'$, then its `refreshTimestamp` must finish after $t'$ and before $t_(s t a r t)$. But this violates the assumption that the last `refreshTimestamp` not after $t_(s t a r t)$ reads out the minimum timestamp at $t'$.

  Therefore, there's no `spsc_dequeue` on $r$ running during $[t', t_(e n d)]$. Therefore, $m i n \- s p s c \- t s(r, t)$ remains constant during $[t', t_(e n d)]$ because it's not `MAX`.

  In conclusion, $m i n \- s p s c \- t s(r, t) lt.eq c$ for $t in[t', t_(e n d)]$.

  We have proved the theorem.
]

#theorem[Given a rank $r$. If within $[t_0, t_1]$, there's no uncompleted `enqueue`s on rank $r$ and all matching `dequeue`s for any completed `enqueue`s on rank $r$ has finished, then $r a n k(n, t) eq.not r$ for every node $n$ and $t in [t_0, t_1]$.] <ltqueue-matched-enqueue-theorem>

#proof[
  If $n$ doesn't lie on the path from root to the leaf node that's attached to the enqueuer node with rank $r$, the theorem obviously holds.

  Due to @ltqueue-one-dequeue-one-enqueue-corollary, there can only one `enqueue` and one `dequeue` at a time at an enqueuer node with rank $r$. Therefore, there is a sequential ordering within the `enqueue`s and a sequential ordering within the `dequeue`s. Therefore, it's sensible to talk about the last `enqueue` before $t_0$ and the last matching `dequeue` $d$ before $t_0$.

  Since all of these `dequeue`s and `enqueue`s work on the same local SPSC and the SPSC is linearizable, $d$ must match the last `enqueue`. After this `dequeue` $d$, the local SPSC is empty.

  When $d$ finishes its *timestamp-refresh phase* at $t_(t s) lt.eq t_0$, due to @ltqueue-refresh-timestamp-theorem, there's at least one successful `refreshTimestamp` call in this phase. Because the last `enqueue` has been matched, $m i n \- t s(r, t) =$ `MAX` for any $t in [t_(t s), t_1]$.

  Similarly, for a leaf node $n_0$, suppose $d$ finishes its *node-$n_0$-refresh phase* at $t_(r\-0) gt.eq t_(t s)$, then $r a n k(n_0, t) =$ `DUMMY` for any $t in [t_(r\-0), t_1]$. $(1)$

  For any non-leaf node $n_i in p a t h(d)$, when $d$ finishes its *node-$n_i$-refresh phase* at $t_(r\-i)$, there's at least one successful `refresh` call during this phase. Suppose this `refresh` call starts and ends at $t_(s t a r t \- i)$ and $t_(e n d\-i)$. Suppose $r a n k(n_(i-1), t) eq.not r$ for $t in [t_(r\-(i-1)), t_1]$. By the way `refresh` is defined after this `refresh` call, $n_i$ will store some rank other than $r$. Because of $(1)$, after this up until $t_1$, $r$ never has a chance to be visible to a `refresh` on node $n_i$ during $[n_(i-1), t]$. In other words, $r a n k(n_i, t) eq.not r$ for $t in [t_(r\-i), t_1]$.

  By induction, we obtain the theorem.
]

#theorem[If an `enqueue` $e$ precedes another `dequeue` $d$, then either:
  - $d$ isn't matched.
  - $d$ matches $e$.
  - $e$ matches $d'$ and $d'$ precedes $d$.
  - $d$ matches $e'$ and $e'$ precedes $e$.
  - $d$ matches $e'$ and $e'$ overlaps with $e$.
] <ltqueue-enqueue-dequeue-theorem>

#proof[
  If $d$ doesn't match anything, the theorem holds. If $d$ matches $e$, the theorem also holds. Suppose $d$ matches $e'$, $e' eq.not e$.

  If $e$ matches $d'$ and $d'$ precedes $d$, the theorem also holds. Suppose $e$ matches $d'$ such that $d$ precedes $d'$ or is unmatched. $(1)$

  Suppose $e$ obtains a timestamp of $c$ and $e'$ obtains a timestamp of $c'$.

  Because $e$ precedes $d$ and because an MPSC does not allow multiple `dequeue`s, from the start of $d$ at $t_0$ until after line 4 of `dequeue` (@ltqueue-dequeue) at $t_1$, $e$ has finished and there's no `dequeue` running that has _actually performed `spsc_dequeue`_. Also by $t_0$ and $t_1$, $e$ is still unmatched due to $(1)$.

  Applying @ltqueue-unmatched-enqueue-corollary, $m i n \- s p s c \- t s(r a n k(r o o t, t_x), t_y) lt.eq c$ for $t_x, t_y in [t_0, t_1]$. Therefore, $d$ reads out a rank $r$ such that $m i n \- s p s c \- t s(r, t) lt.eq c$ for $t in [t_0, t_1]$. Consequently, $d$ dequeues out a value with a timestamp not greater than $c$. Because $d$ matches $e'$, $c' lt.eq c$. However, $e' eq.not e$ so $c' lt c$.

  This means that $e$ cannot precede $e'$, because if so, $c lt c'$.

  Therefore, $e'$ precedes $e$ or overlaps with $e$.
]

#lemma[
  If $d$ matches $e$, then either $e$ precedes or overlaps with $d$.
] <ltqueue-matching-dequeue-enqueue-lemma>

#proof[
  If $d$ precedes $e$, none of the local SPSCs can contain an item with the timestamp of $e$. Therefore, $d$ cannot return an item with a timestamp of $e$. Thus $d$ cannot match $e$.

  Therefore, $e$ either precedes or overlaps with $d$.
]

#theorem[If a `dequeue` $d$ precedes another `enqueue` $e$, then either:
  - $d$ isn't matched.
  - $d$ matches $e'$ such that $e'$ precedes or overlaps with $e$ and $e' eq.not e$.
] <ltqueue-dequeue-enqueue-theorem>

#proof[
  If $d$ isn't matched, the theorem holds.

  Suppose $d$ matches $e'$. Applying @ltqueue-matching-dequeue-enqueue-lemma, $e'$ must precede or overlap with $d$. In other words, $d$ cannot precede $e'$.

  If $e$ precedes or is $e'$, then $d$ must precede $e'$, which is contradictory.

  Therefore, $e'$ must precede $e$ or overlap with $e$.
]

#theorem[If an `enqueue` $e_0$ precedes another `enqueue` $e_1$, then either:
  - Both $e_0$ and $e_1$ aren't matched.
  - $e_0$ is matched but $e_1$ is not matched.
  - $e_0$ matches $d_0$ and $e_1$ matches $d_1$ such that $d_0$ precedes $d_1$.
] <ltqueue-enqueue-enqueue-theorem>

#proof[
  If both $e_0$ and $e_1$ aren't matched, the theorem holds.

  Suppose $e_1$ matches $d_1$. By @ltqueue-matching-dequeue-enqueue-lemma, either $e_1$ precedes or overlaps with $d_1$.

  If $e_0$ precedes $d_1$, applying @ltqueue-enqueue-dequeue-theorem for $d_1$ and $e_0$:
  - $d_1$ isn't matched, contradictory.
  - $d_1$ matches $e_0$, contradictory.
  - $e_0$ matches $d_0$ and $d_0$ precedes $d_1$, the theorem holds.
  - $d_1$ matches $e_1$ and $e_1$ precedes $e_0$, contradictory.
  - $d_1$ matches $e_1$ and $e_1$ overlaps with $e_0$, contradictory.

  If $d_1$ precedes $e_0$, applying @ltqueue-dequeue-enqueue-theorem for $d_1$ and $e_0$:
  - $d_1$ isn't matched, contradictory.
  - $d_1$ matches $e_1$ and $e_1$ precedes or overlaps with $e_0$, contradictory.

  Consider that $d_1$ overlaps with $e_0$, then $d_1$ must also overlap with $e_1$. Call $r_1$ the rank of the enqueuer that performs $e_1$. Call $t$ to be the time $d_1$ atomically reads the root's rank on line 4 of `dequeue` (@ltqueue-dequeue). Because $d_1$ matches $e_1$, $d_1$ must read out $r_1$ at $t_1$.

  If $e_1$ is the first `enqueue` of rank $r_1$, then $t$ must be after $e_1$ has started, because otherwise, due to @ltqueue-matched-enqueue-theorem, $r_1$ would not be in $r o o t$ before $e_1$.

  If $e_1$ is not the first `enqueue` of rank $r_1$, then $t$ must also be after $e_1$ has started. Suppose the contrary, $t$ is before $e_1$ has started:
  - If there's no uncompleted `enqueue` of rank $r_1$ at $t$ and they are all matched by the time $t$, due to @ltqueue-matched-enqueue-theorem, $r_1$ would not be in $r o o t$ at $t$. Therefore, $d_1$ cannot read out $r_1$, which is contradictory.
  - If there's some unmatched `enqueue` of rank $r_1$ at $t$, $d_1$ will match one of these `enqueue`s instead because:
    - There's only one `dequeue` at a time, so unmatched `enqueue`s at $t$ remain unmatched until $d_1$ performs an `spsc_dequeue`.
    - Due to @ltqueue-one-dequeue-one-enqueue-corollary, all the `enqueue`s of rank $r_1$ must finish before another starts. Therefore, there's some unmatched `enqueue` of rank $r_1$ finishing before $e_1$.
    - The local SPSC of the enqueuer node of rank $r_1$ is serializable, so $d_1$will favor one of these `enqueue`s over $e_1$.

  Therefore, $t$ must happen after $e_1$ has started. Right at $t$, no `dequeue` is actually modifying the LTQueue state and $e_0$ has finished. If $e_0$ has been matched at $t$ then the theorem holds. If $e_0$ hasn't been matched at $t$, applying @ltqueue-unmatched-enqueue-theorem, $d_1$ will favor $e_0$ over $e_1$, which is a contradiction.

  We have proved the theorem.
]

#theorem[If a `dequeue` $d_0$ precedes another `dequeue` $d_1$, then either:
  - $d_0$ isn't matched.
  - $d_1$ isn't matched.
  - $d_0$ matches $e_0$ and $d_1$ matches $e_1$ such that $e_0$ precedes or overlaps with $e_1$.
] <ltqueue-dequeue-dequeue-theorem>

#proof[
  If $d_0$ isn't matched or $d_1$ isn't matched, the theorem holds.

  Suppose $d_0$ matches $e_0$ and $d_1$ matches $e_1$.

  Suppose the contrary, $e_1$ precedes $e_0$. Applying @ltqueue-enqueue-dequeue-theorem:
  - Both $e_0$ and $e_1$ aren't matched, which is contradictory.
  - $e_1$ is matched but $e_0$ is not matched, which contradictory.
  - $e_1$ matches $d_1$ and $e_0$ matches $d_0$ such that $d_1$ precedes $d_0$, which is contradictory.

  Therefore, the theorem holds.
]

#theorem[The modified LTQueue algorithm is linearizable.]

#proof[
  Suppose some history $H$ produced from the modified LTqueue algorithm.

  If $H$ contains some pending method calls, we can just wait for them to complete (because the algorithm is wait-free, which we will prove later). Therefore, now we consider all $H$ to contain only completed method calls. So, we know that if a `dequeue` or an `enqueue` in $H$ is matched or not.

  If there are some unmatched `enqueue`s, we can append `dequeue`s sequentially to the end of $H$ until there's no unmatched `enqueue`s. Consider one such $H'$.

  We already have a strict partial order $->$#sub($H'$) on $H'$.

  Because the queue is MPSC, there's already a total order among the `dequeue`s.

  We will extend $->$#sub($H'$) to a strict total order $=>$#sub($H'$) on $H'$ as follows:
  - If $X ->$#sub($H'$)$Y$ then $X =>$#sub($H'$)$Y$. $(1)$
  - If a `dequeue` $d$ matches $e$ then $e =>$#sub($H'$)$d$. $(2)$
  - If a `dequeue` $d_0$ matches $e_0$ and another `dequeue` matches $e_1$ such that $d_0 =>$#sub($H'$)$d_1$ then $e_0 =>$#sub($H'$)$e_1$. $(3)$
  - If a `dequeue` $d$ overlaps with an `enqueue` $e$ but does not match $e$, $d =>$#sub($H'$)$e$. $(4)$

  We will prove that $=>$#sub($H'$) is a strict total order on $H'$. That is, for every pair of different method calls $X$ and $Y$, either exactly one of these is true $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ and for any $X$, $X arrow.double.not$#sub($H'$)$X$.

  It's obvious that $X arrow.double.not$#sub($H'$)$X$.

  If $X$ and $Y$ are `dequeue`s, because there's a total order among the `dequeue`s, either exactly one of these is true: $X ->$#sub($H'$)$Y$ or $Y ->$#sub($H'$)$X$. Then due to $(1)$, either $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$. Notice that we cannot obtain $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ from $(2)$, $(3)$, or $(4)$.
  #linebreak()
  Therefore, exactly one of $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ is true. $(*)$

  If $X$ is `dequeue` and $Y$ is `enqueue`, in this case $(3)$ cannot help us obtain either $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$, so we can disregard it.
  - If $X ->$#sub($H'$)$Y$, then due to $(1)$, $X =>$#sub($H'$)$Y$. By definition, $X$ precedes $Y$, so $(4)$ cannot apply. Applying @ltqueue-dequeue-enqueue-theorem, either
    - $X$ isn't matched, $(2)$ cannot apply. Therefore, $Y arrow.double.not$#sub($H'$)$X$.
    - $X$ matches $e'$ and $e' eq.not Y$. Therefore, $X$ does not match $Y$, or $(2)$ cannot apply. Therefore, $Y arrow.double.not$#sub($H'$)$X$.
    Therefore, in this case, $X arrow.double$#sub($H'$)$Y$ and $Y arrow.double.not$#sub($H'$)$X$.
  - If $Y ->$#sub($H'$)$X$, then due to $(1)$, $Y =>$#sub($H'$)$X$. By definition, $Y$ precedes $X$, so $(4)$ cannot apply. Even if $(2)$ applies, it can only help us obtain $Y =>$#sub($H'$)$X$.
    #linebreak() Therefore, in this case, $Y arrow.double$#sub($H'$)$X$ and $X arrow.double.not$#sub($H'$)$Y$.
  - If $X$ overlaps with $Y$:
    - If $X$ matches $Y$, then due to $(2)$, $Y =>$#sub($H'$)$X$. Because $X$ matches $Y$, $(4)$ cannot apply. Therefore, in this case $Y =>$#sub($H'$)$X$ but $X arrow.double.not$#sub($H'$)$Y$.
    - If $X$ does not match $Y$, then due to $(4)$, $X =>$#sub($H'$)$Y$. Because $X$ doesn't match $Y$, $(2)$ cannot apply. Therefore, in this case $X =>$#sub($H'$)$Y$ but $Y arrow.double.not$#sub($H'$)$X$.
  Therefore, exactly one of $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ is true. $(**)$

  If $X$ is `enqueue` and $Y$ is `enqueue`, in this case $(2)$ and $(4)$ are irrelevant:
  - If $X ->$#sub($H'$)$Y$, then due to $(1)$, $X =>$#sub($H'$)$Y$. By definition, $X$ precedes $Y$. Applying @ltqueue-enqueue-enqueue-theorem,
    - Both $X$ and $Y$ aren't matched, then $(3)$ cannot apply. Therefore, in this case, $Y arrow.double.not$#sub($H'$)$X$.
    - $X$ is matched but $Y$ is not matched, then $(3)$ cannot apply. Therefore, in this case, $Y arrow.double.not$#sub($H'$)$X$.
    - $X$ matches $d_x$ and $Y$ matches $d_y$ such that $d_x$ precedes $d_y$, then $(3)$ applies and we obtain $X arrow.double$#sub($H'$)$Y$.
    Therefore, in this case, $X arrow.double$#sub($H'$)$Y$ but $Y arrow.double.not$#sub($H'$)$X$.
  - If $Y ->$#sub($H'$)$X$, this case is symmetric to the first case. We obtain $Y arrow.double$#sub($H'$)$X$ but $X arrow.double.not$#sub($H'$)$Y$.
  - If $X$ overlaps with $Y$, because in $H'$, all `enqueue`s are matched, then, $X$ matches $d_x$ and $d_y$. Because $d_x$ either precedes or succeeds $d_y$, Applying $(3)$, we obtain either $X arrow.double$#sub($H'$)$Y$ or $Y arrow.double$#sub($H'$)$X$ and there's no way to obtain the other.
  Therefore, exactly one of $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ is true. $(***)$

  From $(*)$, $(**)$, $(***)$, we have proved that $=>$#sub($H'$) is a strict total ordering that is consistent with $->$#sub($H'$). In other words, we can order method calls in $H'$ in a sequential manner. We will prove that this sequential order is consistent with FIFO semantics:
  - An item can only be `dequeue`d once: This is trivial as a `dequeue` can only match one `enqueue`.
  - Items are `dequeue`d in the order they are `enqueue`d: Suppose there are two `enqueue`s $e_1$, $e_2$ such that $e_1 arrow.double$#sub($H'$)$e_2$ and suppose they match $d_1$ and $d_2$. Then we have obtained $e_1 arrow.double$#sub($H'$)$e_2$ either because:
    - $(3)$ applies, in this case $d_1 arrow.double$#sub($H'$)$d_2$ is a condition for it to apply.
    - $(1)$ applies, then $e_1$ precedes $e_2$, by @ltqueue-enqueue-enqueue-theorem, $d_1$ must precede $d_2$, thus $d_1 arrow.double$#sub($H'$)$d_2$.
    Therefore, if $e_1 arrow.double$#sub($H'$)$ e_2$ then $d_1 arrow.double$#sub($H'$)$d_2$.
  - An item can only be `dequeue`d after it's `enqueue`d: Suppose there is an `enqueue` $e$ matched by $d$. By $(2)$, obviously $e =>$#sub($H'$)$d$.
  - If the queue is empty, `dequeue`s return nothing. Suppose a dequeue $d$ such that any $e arrow.double$#sub($H'$)$d$ is all matched by some $d'$ and $d' arrow.double$#sub($H'$)$d$, we will prove that $d$ is unmatched. By @ltqueue-matching-dequeue-enqueue-lemma, $d$ can only match an `enqueue` $e_0$ that precedes or overlaps with $d$.
    - If $e_0$ precedes $d$, by our assumption, it's already matched by another `dequeue`.
    - If $e_0$ overlaps with $d$, by our assumption, $d arrow.double$#sub($H'$)$e_0$ because if $e_0 arrow.double$#sub($H'$)$d$, $e_0$ is already matched by another $d'$. Then, we can only obtain this because $(4)$ applies, but then $d$ does not match $e_0$.
    Therefore, $d$ is unmatched.

  In conclusion, $=>$#sub($H'$) is a way we can order method calls in $H'$ sequentially that conforms to FIFO semantics. Therefore, we can also order method calls in $H$ sequentially that conforms to FIFO semantics as we only append `dequeue`s sequentially to the end of $H$ to obtain $H'$.

  We have proved the theorem.
]

== ABA problem

ABA problem is unlikely to occur, because any CAS usage increases the value of a monotonic tag.

== Memory safety

Memory allocation and deallocation are performed only in the SPSC data structure. Since @ltqueue has proved that it's memory-safe, the modified algorithm is also memory-safe.

== Wait-freedom

All the procedures `enqueue`, `dequeue`, `refresh`, `refreshTimestamp`, `refreshLeaf`, `propagate` are wait-free because there's no possibility of inifinite loops and a process waiting for another process.

#bibliography("/bibliography.yml", title: [References])
