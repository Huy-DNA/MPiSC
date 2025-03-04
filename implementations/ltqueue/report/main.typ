#let title = [
  Modified LTQueue without Load-Link/Store-Conditional]

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

#show figure.where(kind: "algorithm"): set align(start)

#import "@preview/lovelace:0.3.0": *
#import "@preview/lemmify:0.1.7": *
#let (
  definition,
  theorem,
  lemma,
  corollary,
  remark,
  proposition,
  example,
  proof,
  rules: thm-rules,
) = default-theorems("thm-group", lang: "en")
#show: thm-rules

= Original LTQueue

The original algorithm is given in @ltqueue by Prasad Jayanti and Srdjan Petrovic in 2005. LTQueue is a wait-free MPSC algorithm, with logarithmic-time for both enqueue and dequeue. The algorithm achieves good scalability by distributing the "global" queue over $n$ queues that are local to each enqueuer. This helps avoid contention on the global queue among the enqueuers and allows multiple enqueuers to succeed at the same time. Furthermore, each enqueue and dequeue is efficient: they are wait-free and guaranteed to complete in $theta(log n)$ where $n$ is the number of enqueuers. This is possible due to the novel tree structure proposed by the authors.

== Local queue algorithm

Each local queue in LTQueue is an SPSC that allows an enqueuer and a dequeuer to concurrently access. This suffices as only the enqueuer that the queue is local to and the one-and-only dequeuer ever access the local queue.

This section presents the SPSC data structure proposed in @ltqueue. Beside the usual `enqueue` and `dequeue` procedures, this SPSC also supports the `readFront` procedure, which allows the enqueuer and dequeuer to retrieve the first item in the SPSC. Notice that enqueuer and dequeuer each has its own `readFront` method.

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of data stored in linked-list's nodes
    + `node_t` = The type of linked-link's nodes
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
) <spsc-enqueue>
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
) <spsc-enqueuer-readFront>

Dequeuer's procedures are given as follows.

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
) <spsc-dequeue>

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
) <spsc-dequeuer-readFront>

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

Note that compare to the original paper @ltqueue, we have make some trivial modification on line 11-12 to handle the leaf node case, which was left unspecified in the original algorithm. In many ways, this modification is in the same light with the mechanism the algorithm is already using, so intuitively, it should not affect the algorithm's correctness or wait-freedom. Note that on line 25 of `refreshLeaf`, we omit which version of `spsc_readFront` it's calling, simply assume that the dequeuer and the enqueuer should call their corresponding version of `spsc_readFront`.

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

Similarly, the proofs of LTQueue's linearizability, wait-freedom, memory-safety and logarithmic-time complexity of enqueue and dequeue operations are given in @ltqueue. One notable technique that allows LTQueue to be both correct and wait-free is the double-refresh trick during the propagation process on line 16-17.

The idea behind the `propagate` procedure is simple: Each time an SPSC queue is modified (inserted/deleted), the timestamp of a leaf has changed so the timestamps of all nodes on the path from that leaf to the root can potentially change. Therefore, we have to propagate the change towards the root, starting from the leaf (line 11-18).

The `refresh` procedure is by itself simple: we access all child nodes to determine the minimum timestamp and try to set the current node's timestamp with the determined minimum timestamp using a pair of LL/SC. However, LL/SC can not always succeed so the current node's timestamp may not be updated by `refresh` at all. The key to fix this is to retry `refresh` on line 17 in case of the first `refresh`'s failure. Later, when we prove the correctness of the modified LTQueue, we provide a formal proof of why this works. Here, for intuition, we visualize in @double-refresh the case where both `refresh` fails but correctness is still ensures.


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

The SPSC data structure in the original LTQueue is kept in tact so one may refer to @spsc-enqueue, @spsc-enqueuer-readFront, @spsc-dequeue, @spsc-dequeuer-readFront for the supported SPSC procedures.

The followings are the rewritten LTQueue's algorithm without LL/SC.

#pagebreak()

The structure of LTQueue is modified as in @modified-ltqueue-tree. At the bottom *enqueuer nodes* (represented by the type `enqueuer_t`), besides the local SPSC, the minimum-timestamp among the elements in the SPSC is also stored. The *internal nodes* no longer store a timestamp but a rank of an enqueuer. This rank corresponds to the enqueuer with the minimum timestamp among the node's children's ranks. Note that if a local SPSC is empty, the minimum-timestamp of the corresponding bottom node is set to `MAX` and its leaf node's rank is set to a `DUMMY` rank.

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
    + `count = FAA(counter)                        `
    + `timestamp = (count, rank)`
    + `spsc_enqueue(enqueuers[rank].spsc, (value, timestamp))`
    + `propagate(rank)`
  ],
) <lt-enqueue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 4,
    booktabs: true,
    numbered-title: [`dequeue()` *returns* `data_t`],
  )[
    + `[rank, version] = root->rank               `
    + *if* `(rank == DUMMY)` *return* $bot$
    + `ret = spsc_dequeue(enqueuers[rank].spsc)`
    + `propagate(rank)`
    + *return* `ret.val`
  ],
) <lt-dequeue>

We omit the description of procedures `parent`, `leafNode`, `children`, leaving how the tree is constructed and children-parent relationship is determined to the implementor. The tree structure used by LTQueue is read-only so a wait-free implementation of these procedures is trivial.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 9,
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
    + *until* `currentNode == root(T)`
  ],
) <lt-propagate>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 19,
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
    + `CAS(&currentNode->rank, [old-rank, old-version], [min-rank, old-version + 1])`
  ],
) <lt-refresh>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 23,
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
) <lt-refresh-timestamp>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 29,
    booktabs: true,
    numbered-title: [`refreshLeaf(rank: uint32_t)`],
  )[
    + `leafNode = leafNode(spsc)                      `
    + `[old-rank, old-version] = leafNode->rank`
    + `[timestamp, ...] = enqueuers[rank].timestamp`
    + `CAS(&leafNode->rank, [old-rank, old-version], [timestamp == MAX ? DUMMY : rank, old-version + 1])`
  ],
) <lt-refresh-leaf>

Notice that we omit which version of `spsc_readFront` we're calling on line 25, simply assuming that the producer and each enqueuer are calling their respective version.

= Proof of correctness

This section proves that the algorithm given in the last section is linearizable, memory-safe and wait-free.

== Linearizability

Within the next two sections, we formalize what it means for an MPSC to be linearizable.

=== Definition of linearizability

The following discussion of linearizability is based on @art-of-multiprocessor-programming by Herlihy and Shavit.

For a concurrent object `S`, we can call some methods on `S` concurrently. A method call on the object `S` is said to have an *invocation event* when it starts and a *response event* when it ends.

#definition[An *invocation event* is a triple $(S, t, a r g s)$, where $S$ is the object the method is invoked on, $t$ is the timestamp of when the event happens and $a r g s$ is the arguments passed to the method call.]

#definition[A *response event* is a triple $(S, t, r e s)$, where $S$ is the object the method is invoked on, $t$ is the timestamp of when the event happens and $r e s$ is the results of the method call.]

#definition[A *method call* is a tuple of $(i, r)$ where $i$ is an invocation event and $r$ is a response event or the special value $bot$ indicating that its response event haven't happened yet. A well-formed *method call* should have a reponse event with a larger timestamp than its invocation event or the response event haven't happened yet.]

#definition[A *method call* is *pending* if its invocation event is $bot$.]

#definition[A *history* is a set of well-formed *method calls*.]

#definition[An extension of *history* $H$ is a *history* $H'$ such that any pending method call is given a response event such that the resulting method call is well-formed.]

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

An MPSC has the same *sequential specification* as a FIFO: `dequeue` returns values in the same order as they was `enqueue`d.

An MPSC places a special constraint on *the set of histories* it can produce: Any history $H$ must not have overlapping `dequeue` method calls.

#definition[An MPSC is *linearizable* if and only if any history produced from the MPSC that does not have overlapping `dequeue` method calls is _linearizable_ according to the _FIFO sequential specification_.]

=== Proof of linearizability

#definition[An `enqueue` operation $e$ is said to *match* a `dequeue` operation $d$ if $d$ returns a timestamp that $e$ enqueues. Similarly, $d$ is said to match $e$. In this case, both $e$ and $d$ are said to be *matched*.]

#definition[An `enqueue` operation $e$ is said to be *unmatched* if no `dequeue` operation *matches* it.]

#definition[A `dequeue` operation $d$ is said to be *unmatched* if no `enqueue` operation *matches* it, in other word, $d$ returns $bot$.]

#theorem[Only the dequeuer and an enqueuer can operate on its enqueuer node.]

#proof[This is trivial.]

We immediately obtain the following result.

#corollary[Only one `dequeue` operation and one `enqueue` operation can operate concurrently on an enqueuer node.] <one-dequeue-one-enqueue-corollary>

#proof[This is trivial.]

#theorem[The SPSC at an enqueuer node contains items with increasing timestamps.] <increasing-timestamp-theorem>

#proof[
  Each `enqueue` would `FAA` the shared counter (line 1 in @lt-enqueue) and enqueue into the local SPSC an item with the timestamp obtained from the counter. Applying @one-dequeue-one-enqueue-corollary, we know that items are enqueued one at a time into the SPSC. Therefore, later items are enqueued by later `enqueue`s, which obtain increasing values by `FFA`-ing the shared counter. The theorem holds.
]

#definition[For a tree node $n$, the enqueuer rank stored in $n$ at time $t$ is denoted as $r a n k(n, t)$.]

#definition[For an `enqueue` or a `dequeue` $op$, the rank of the enqueuer it affects is denoted as $r a n k(op)$.]

#definition[For an enqueuer whose rank is $r$, the `min-timestamp` value stored in its enqueuer node at time $t$ is denoted as $m i n \- t s(r, t)$. If $r$ is `DUMMY`, $m i n \- t s(r, t)$ is `MAX`.]

#definition[For an enqueuer with rank $r$, the minimum timestamp among the elements between `First` and `Last` in the local SPSC at time $t$ is denoted as $m i n \- s p s c \- t s(r, t)$. If $r$ is dummy, $m i n \- s p s c \- t s(r, t)$ is `MAX`.]

#definition[For an `enqueue` or a `dequeue` $op$, the set of nodes that it calls `refresh` or `refreshLeaf` on is denoted as $p a t h(op)$.]

#definition[For an `enqueue` or a `dequeue`, *timestamp-refresh phase* refer to its execution of line 10-11 in `propagate` (@lt-propagate).]

#definition[For an `enqueue` or a `dequeue` $op$, and a node $n in p a t h(op)$, *node-$n$-refresh phase* refer to its execution of line 12-13 (if $n$ is a leaf node) and line 17-18 (if $n$ is a non-leaf node) to refresh $n$'s rank in `propagate` (@lt-propagate).]

#definition[`refreshTimestamp` is said to start its *CAS-sequence* if it finishes line 24 in @lt-refresh-timestamp. `refreshTimestamp` is said to end its *CAS-sequence* if it finishes line 27 or line 28 in @lt-refresh-timestamp.]

#definition[`refresh` is said to start its *CAS-sequence* if it finishes line 20 in @lt-refresh. `refresh` is said to end its *CAS-sequence* if it finishes line 30 in @lt-refresh.]

#definition[`refreshLeaf` is said to start its *CAS-sequence* if it finishes line 31 in @lt-refresh-leaf. `refreshLeaf` is said to end its *CAS-sequence* if it finishes line 33 in @lt-refresh-leaf.]

#theorem[For an `enqueue` or a `dequeue` $op$, if $op$ modifies an enqueuer node and this enqueuer node is attached to a leaf node $l$, then $p a t h(op)$ is the set of nodes lying on the path from $l$ to the root node.]

#proof[This is trivial considering how `propagate` (@lt-propagate) works.]

#definition[Given a subtree rooted at $n$, $overparen(E)(n)$ is the set of enqueuers that have an enqueuer node attached to a leaf node in this subtree.]

#theorem[For any time $t$ and a node $n$, $r a n k(n, t) in overparen(E)(n) union {$`DUMMY`$}$.] <possible-ranks-theorem>

#proof[This is trivial considering how `refresh` and `refreshLeaf` works.]

#theorem[If an `enqueue` or a `dequeue` $op$ begins its *timestamp-refresh phase* at $t_0$ and finishes at time $t_1$, there's always at least one successful `refreshTimestamp` on $r a n k(op)$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$.] <refresh-timestamp-theorem>

#proof[
  If one of the two `refreshTimestamp`s succeeds, then we have obtain the theorem.

  Consider the case where both fail.

  The first `refreshTimestamp` fails because there's another `refreshTimestamp` ending its *CAS-sequence* successfully after $t_0$ but before the end of the first `refreshTimestamp`'s *CAS-sequence*.

  Suppose the contrary that there's no successful `refreshTimestamp` on $r a n k(op)$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$. Then, the second `refreshTimestamp` must succeed, because during after the first `refreshTimestamp` and before $t_1$, no other `refreshTimestamp` successfully finishes its *CAS-sequence*.

  We have proved the theorem.
]

#theorem[If an `enqueue` or a `dequeue` begins its *node-$n$-refresh phase* at $t_0$ and finishes at $t_1$, there's always at least one successful `refresh()` or `refreshLeaf()` on $n$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$.] <refresh-node-theorem>

#proof[This is similar to the above proof.]

#theorem[For any node $n$, $m i n \- t s(r a n k(n, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_0, t_1]$ if within $t_0$ and $t_1$, any `dequeue` $d$ where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*.] <monotonic-theorem>

#proof[
  We have the assumption that within $t_0$ and $t_1$, there's no `dequeue` where $n in p a t h(d)$ or hasn't finished its *node-$n$-refresh phase*. Notice that if $n$ satisfies this assumption, any child of $n$ also satisfies this assumption. We will work from the leaf nodes onwards.

  We will prove a stronger version of this theorem: Given a node $n$, time $t_0$ and $t_1$ such that within $[t_0, t_1]$, any `dequeue` $d$ where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*. Take $t_s (n)$ and $t_e (n)$ to be the starting and ending time of the last successful `refresh` call on $n$ during the last `dequeue`'s *node-$n$-refresh phase* not later than $t_0$, or if there is none, $t_s (n) = t_e (n) = 0$. Then, $m i n \- t s(r a n k(n, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_e (n), t_1]$.

  Consider any enqueuer node of rank $r$ that's attached to a satisfied leaf node. For any $n'$ that is a descendant of $n$, during $t_s (n')$ and $t_1$, the local SPSC of this enqueuer node can only be enqueued. Because:
  - If a `dequeue` starts between $t_0$ and $t_1$, it hasn't finished its *node-$n'$-refresh phase*.
  - If a `dequeue` starts between $t_s (n')$ and $t_0$, then its *node-$n'$-refresh phase* must start before $t_0$, but this violates our assumption that $t_s (n')$ is the starting time of the last `dequeue`'s *node-$n$-refresh phase* not later than $t_0$.
  Therefore, $m i n \- s p s c \- t s(r, t_x)$ can only decrease from `MAX` to some timestamp and remain constant for $t_x in [t_s (n'), t_1]$. Such is also the case for $m i n \- t s (r, t_x)$. $(1)$

  Consider any satisfied leaf node $n_0$. Any successful `refreshLeaf` during $[t_e (n_0), t_1]$ can only set $r a n k(n_0, t_x)$ to $r$, which is the rank of the enqueuer node its attached to. This is because `refreshLeaf` is called after a *timestamp-refresh phase* and by theorem @refresh-timestamp-theorem, there must already be a successful `refresh` before this and because of $(1)$, `refreshLeaf` cannot set $r a n k(n_0, t_x)$ to `DUMMY` (the only other possible value for it by @possible-ranks-theorem). Therefore, combining with $(1)$, $m i n \- t s(r a n k(n_0, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_e (n_0), t_1]$. $(2)$

  Consider any satisfied non-leaf node $n'$ that is a descendant of $n$. Suppose during $[t_e (n'), t_1]$, we have a sequence of successful `refresh` calls that start their CAS-sequences at $t_(s t a r t \- 0) lt t_(s t a r t \- 1) lt t_(s t a r t \- 2) lt ... lt t_(s t a r t \- k)$ and end them at $t_(e n d \- 0) lt t_(e n d \- 1) lt t_(e n d\- 2) lt ... lt t_(e n d \- k)$. By definition, $t_(e n d \- 0) = t_e (n')$. We can prove that $t_(e n d \- i) < t_(s t a r t \- (i+1))$ because successful CAS-sequences cannot overlap.

  Due to how `refresh` is defined, for any $k gt.eq i gt.eq 1$:
  - Suppose $t_(r a n k\-i)(c)$ is the time `refresh` reads the rank stored in the child node $c$, so $t_(s t a r t \- i) lt.eq t_(r a n k\-i)(c) lt.eq t_(e n d \- i)$.
  - Suppose $t_(t s\-i)(c)$ is the time `refresh` reads the timestamp stored in an enqueuer with the rank read previously, so $t_(s t a r t \- i) lt.eq t_(t s\-i)(c) lt.eq t_(e n d \- i)$.
  - There exists a child $c_i$ such that $r a n k(n', t_(e n d \- i)) = r a n k(c_i, t_(r a n k\-i)(c_i))$. $(3)$
  - For every child $c$ of $n'$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-i)(c)), t_(t s\-i)(c))$. $(4)$

  Suppose the stronger theorem already holds for every child $c$ of $n'$. $(5)$

  We have $t_e (c) lt.eq t_s(n') lt.eq t_(s t a r t \-(i-1)) lt.eq t_(r a n k\-(i-1))(c) lt.eq t_(e n d \-(i-1)) lt.eq t_(r a n k \- i)(c)$ for any $i gt.eq 1$. Combining with $(4)$, $(5)$, we have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-i)(c)), t_(t s\-i)(c))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-(i-1))(c)), t_(t s\-i)(c))$.

  Choose $c = c_(i-1)$ as in $(3)$. We have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c_(i-1), t_(r a n k\-(i-1))(c_(i-1))),$$ t_(t s\-i)(c_(i-1)))$ #linebreak() $= m i n\- t s(r a n k(n', t_(e n d \- (i-1))), t_(t s \-i)(c_(i-1))$.

  Because $t_(t s \-i)(c_i) lt.eq t_(e n d \- i)$ and $t_(t s \-i)(c_(i-1)) gt.eq t_(e n d \- (i-1))$ and $(1)$, we have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(e n d\-i))$ #linebreak() $lt.eq m i n \- t s (r a n k(n', t_(e n d \- (i-1))), t_(e n d \- (i-1)))$. $(*)$

  $r a n k(n', t_x)$ can only change after each successfully `refresh`, therefore, the sequence of its value is $r a n k(n', t_(e n d \- 0))$, $r a n k(n', t_(e n d \- 1))$, ..., $r a n k(n', t_(e n d \- k))$. $(**)$

  Note that if `refresh` observes that an enqueuer has a `min-timestamp` of `MAX`, it would never try to CAS $n'$'s rank to the rank of that enqueuer (line 22 and line 27 of @lt-refresh). So, if `refresh` actually set the rank of $n'$ to some non-dummy value, the corresponding enqueuer must actually has a non-`MAX` `min-timestamp` _at some point_. Due to $(1)$, this is constant during $t_s (n')$ and $t_1$. Therefore, $m i n \- t s(r a n k(n', t_(e n d \- i)), t))$ is constant for any $t gt.eq t_(e n d \- i)$ and $k gt.eq i gt.eq 1$. $m i n \- t s(r a n k(n', t_(e n d \- 0)), t))$ is constant for any $t gt.eq t_(e n d \- 0)$ if there's a `refresh` before $t_0$. If there's no `refresh` before $t_0$, it is constant `MAX`. So, $m i n \- t s(r a n k(n', t_(e n d \- i)), t))$ is constant for any $t gt.eq t_(e n d \- i)$ and $k gt.eq i gt.eq 0$. $(***)$

  Combining $(*)$, $(**)$, $(***)$, we obtain the stronger version of the theorem.
]

#theorem[If an `enqueue` $e$ obtains a timestamp $c$ and finishes at time $t_0$ and is still *unmatched* at time $t_1$, then for any subrange $T$ of $[t_0, t_1]$ that does not overlap with a `dequeue`, $m i n \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.]

#proof[
  We will prove a stronger version of this theorem: Suppose an `enqueue` $e$ obtains a timestamp $c$ and finishes at time $t_0$ and is still *unmatched* at time $t_1$. For every $n_i in p a t h(e)$, $n_0$ is the leaf node and $n_i$ is the parent of $n_(i-1)$, $i gt.eq 1$. If $e$ starts and finishes its *node-$n_i$-refresh phase* at $t_(s t a r t\-i)$ and $t_(e n d\-i)$ then for any subrange $T$ of $[t_(e n d\-i), t_1]$ that does not overlap with a `dequeue` $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node $n_i$ refresh phase*, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  If $t_1 lt t_0$ then the theorem holds.

  Take $r_e$ to be the rank of the enqueuer that performs $e$.

  Suppose $e$ enqueues an item with the timestamp $c$ into the local SPSC at time $t_(e n q u e u e)$. Because it's still unmatched up until $t_1$, $c$ is always in the local SPSC during $t_(e n q u e u e)$ to $t_1$. Therefore, $m i n \- s p s c \- t s(r_e) lt.eq c$. $(1)$

  Suppose $e$ finishes its *timestamp refresh phase* at $t_(r\-t s)$. Because $t_(r\-t s) gt.eq t_(e n q u e u e)$. Due to $(1)$, $m i n \- t s(r_e, t) lt.eq c$ for every $t_(r\-t s) lt.eq t lt.eq t_1$. $(2)$

  Consider the leaf node $n_0 in p a t h (e)$. Only one $e$ and another `dequeue` can refresh $n_0$'s rank. Due to $(2)$, $r a n k(n_0, t)$ is always $r_e$ for any $t in [t_(e\-i), t_1]$. Also due to $(2)$, $m i n \- t s(r a n k(n_0, t_r), t_s) lt.eq c$ for any $t_r, t_s in [t_(e n d\-i), t_1]$.

  Consider any non-leaf node $n_i in p a t h(e)$. We can extend any subrange $T$ to the left until we either:
  - Reach a `dequeue` $d$ such that $n_i in p a t h (d)$ and $d$ has just finished its *node-$n_i$-refresh phase*.
  - Reach $t_(e n d \- i)$.
  Consider one such subrange $T_i$.

  Notice that $T_i$ always starts right after a *node-$n_i$-refresh phase*. Due to @refresh-node-theorem, there's always at least one successful `refresh` in this *node-$n_i$-refresh phase*.

  Suppose the stronger version of the theorem already holds for $n_(i-1)$. That is, if $e$ starts and finishes its *node-$n_(i-1)$-refresh phase* at $t_(s t a r t\-(i-1))$ and $t_(e n d\-(i-1))$ then for any subrange $T$ of $[t_(e n d\-(i-1)), t_1]$ that does not overlap with a `dequeue` $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node $n_(i-1)$ refresh phase*, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  Extend $T_i$ to the left until we either:
  - Reach a `dequeue` $d$ such that $n_i in p a t h (d)$ and $d$ has just finished its *node-$n_(i-1)$-refresh phase*.
  - Reach $t_(e n d \- (i-1))$.
  Take the resulting range to be $T_(i-1)$. Obviously, $T_i subset T_(i-1)$.

  $T_(i-1)$ satisifies both criteria:
  - It's a subrange of $[t_(e n d\-(i-1)), t_1]$.
  - It does not overlap with a `dequeue` $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node-$n_(i-1)$-refresh phase*.
  Therefore, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_(i-1)$.

  Consider the last successful `refresh` on $n_i$ ending not after $T_i$, take $t_s'$ and $t_e'$ to be the start and end time of this `refresh`'s CAS-sequence. Because right at the start of $T_i$, a *node-$n_i$-refresh phase* just ends, this `refresh` must be within this *node-$n_i$-refresh phase*. $(4)$

  This `refresh`'s CAS-sequence must be within $T_(i-1)$. This is because right at the start of $T_(i-1)$, a *node-$n_(i-1)$-refresh phase* just ends and $T_(i-1) supset T_i$, it must have covered the *node-$n_i$-refresh phase* whose end $T_i$ starts from and combining with $(4)$. Therefore, $t_s' in T_(i-1)$ and $t_e' in T_i$. $(5)$

  Due to how `refresh` is defined and the fact that $n_(i-1)$ is a child of $n_i$:
  - $t_(r a n k)$ is the time `refresh` reads the rank stored in $n_(i-1)$, so that $t_s' lt.eq t_(r a n k) lt.eq t_e'$. Combining with $(5)$, $t_(r a n k) in T_(i-1)$.
  - $t_(t s)$ is the time `refresh` reads the timestamp from that rank $t_s' lt.eq t_(t s) lt.eq t_e'$. Combining with $(5)$, $t_(t s) in T_(i-1)$.
  - There exists a time $t'$, $t_s' lt.eq t' lt.eq t_e'$, #linebreak() $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq m i n \- t s (r a n k(n_(i-1), t_(r a n k)), t_(t s))$. $(6)$

  From $(6)$ and the fact that $t_(r a n k) in T_(i-1)$ and $t_(t s) in T_(i-1)$, $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq c$.

  There shall be no `dequeue` starting within $t_s'$ till the end of $T_i$ because:
  - If there's a `dequeue` starting within $T_i$, then $T_i$'s assumption is violated.
  - If there's a `dequeue` starting after $t_s'$ but before $T_i$, it must finish its *node-$n_i$-refresh phase* before $T_i$. However, then $t_e'$ is no longer the end of the last successful `refresh` on $n_i$ not after $T_i$.
  Because there's no `dequeue` starting in this timespan, $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq m i n \- t s(r a n k(n_i, t_e'), t_e') lt.eq c$.

  If there's no `dequeue` between $t_e'$ and the end of $T_i$ whose *node-$n_i$-refresh phase* hasn't finished, then by @monotonic-theorem, $m i n \- t s(r a n k(n_i, t_r), t_s)$ is monotonically decreasing for any $t_r$, $t_s$ starting from $t_e'$ till the end of $T_i$. Therefore, $m i n \- t s (r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_i$.

  Suppose there's a `dequeue` whose *node-$n_i$-refresh phase* is in progress some time between $t_e'$ and the end of $T_i$. By definition, this `dequeue` must finish it before $T_i$. Because $t_e'$ is the time of the last successful `refresh` on $n_i$ before $T_i$, $t_e'$ must be within the *node-$n_i$-refresh phase* of this `dequeue` and there should be no `dequeue` after that. By the way, $t_e'$ is defined, technically, this `dequeue` has finished its *node-$n_i$-refresh phase* right at $t_e'$. Therefore, similarly, we can apply @monotonic-theorem, $m i n \- t s (r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_i$.

  By induction, we have proved the stronger version of the theorem.
]

#theorem[If an `enqueue` $e$ precedes another `dequeue` $d$, then either:
  - $d$ isn't matched.
  - $d$ matches $e$.
  - $d$ matches $e'$ and $e'$ precedes $e$.
  - $d$ matches $e'$ and $e'$ overlaps with $e$.
]

#proof[
]

#theorem[If an `enqueue` $e_0$ precedes another `enqueue` $e_1$, then either:
  - Both $e_0$ and $e_1$ aren't matched.
  - $e_0$ is matched but $e_1$ is not matched.
  - Both $e_0$ and $e_1$ are matched.
]

#theorem[If a `dequeue` $d_0$ precedes another `dequeue` $d_1$, then either:
  - $d_0$ isn't matched.
  - $d_1$ isn't matched.
  - $d_0$ matches $e_0$ and $d_1$ matches $e_1$ such that $e_0$ precedes or overlaps with $e_1$.
]

#theorem[If a `dequeue` $d$ precedes another `enqueue` $e$, then either:
  - $d$ isn't matched.
  - $d$ matches $e'$ such that $e'$ precedes or overlaps with $e$.
]

== Memory safety

== Wait-freedom

#bibliography("/bibliography.yml", title: [References])
