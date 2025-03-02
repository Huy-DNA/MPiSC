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

#definition[For an enqueuer $E$, its rank is denoted as $r a n k(E)$.]

#definition[For an enqueuer $E$ whose rank is $r$, the `min-timestamp` value stored in its enqueuer node at time $t$ is denoted as $m i n \- t s(r, t)$. If $r$ is `DUMMY`, $m i n \- t s(r, t)$ is `MAX`.]

#definition[For an enqueuer $E$, the minimum timestamp among the elements between `First` and `Last` in the local SPSC at time $t$ is denoted as $m i n \- s p s c \- t s(E, t)$. If $E$ is dummy, $m i n \- s p s c \- t s(E, t)$ is `MAX`.]

#definition[For an `enqueue` $e$, the set of nodes that it calls `refresh` or `refreshLeaf` on is denoted as $p a t h(e)$.]

#definition[For an `dequeue` $d$, the set of nodes that it calls `refresh` or `refreshLeaf` on is denoted as $p a t h(d)$.]

#theorem[For an `enqueue` $e$, if $e$ modifies an enqueuer node and this enqueuer node is attached to a leaf node $l$, then $p a t h(e)$ is the set of nodes lying on the path from $l$ to the root node.]

#proof[This is trivial considering how `propagate` (@lt-propagate) works.]

#definition[Given a subtree rooted at $n$, $overparen(E)(n)$ is the set of enqueuers that have an enqueuer node attached to a leaf node in this subtree.]

#theorem[For any time $t$ and a node $n$, $r a n k(n, t) in overparen(E)(n) union {$`DUMMY`$}$.] <possible-ranks-theorem>

#proof[This is trivial considering how `refresh` and `refreshLeaf` works.]

#definition[A non-leaf node $n$ is said to be *consistent* at time $t$ with respect to time $t_0$, with $t_0 lt.eq t$, if for every child node $c$ of $n$, there exists a time $t_r$, $t_s$, $t_0 lt.eq t_r, t_s lt.eq t$, such that $m i n \- t s(r a n k(n, t), t_s) lt.eq m i n \- t s(r a n k(c, t_r), t_s)$, furthermore, there exists a child node $c$ of $n$ such that $r a n k(n, t) = r a n k(c, t_r)$.
]

#definition[A leaf node $n$ is said to be *consistent* at time $t$ with respect to time $t_0$, with $t_0 lt.eq t$, if there exists a time $t_s$, $t_0 lt.eq t_r lt.eq t$, such that $m i n \- t s(r a n k(n, t), t_s) = m i n \- t s(r a n k(E), t_s)$ with $E$ being the enqueuer attached to $n$.
]

#theorem[At some time $t=delta$, with $delta$ arbitrarily small, any node is *consistent* with respect to $t = delta'$ for any $delta' lt.eq delta$.]

#proof[This is trivial. After initialization, the modified LTQueue is in an empty state from time $t=0$ up until the first operation. We can take $delta$ to be a time point right before the first operation.]

#theorem[Consider an `enqueue` or `dequeue` operation. Take $N$ to be the set of nodes that this `enqueue` calls `refreshLeaf` or `refresh` on. Suppose $t_0$ is the time the first `refresh` or `refreshLeaf` is called by the `enqueue` or `dequeue`. Suppose $t_1$ is the time the last `refresh` or `refreshLeaf` is finished by the `enqueue` or `dequeue`. Then, for any node $n in N$, $n$ is consistent at time $t_1$ with respect to time $t_0$.] <refresh-retry-theorem>

#proof[
  Consider a node $n in N$.

  We refer to `refresh(`$n$`)` and `refreshLeaf(`$n$`)` as an $n$-refresh call.

  We will prove that there's some $n$-refresh call (can be called by some other enqueuer or dequeuer) that starts and ends successfully between $t_0$ and $t_1$. $(*)$

  Consider the current enqueuer or dequeuer's $n$ refresh calls:
  - If one of the $n$-refresh calls succeeds in `propagate` (@lt-propagate) then obviously $(*)$ holds.
  - Both $n$-refresh calls fail. Suppose that $(*)$ doesn't hold. Then, the first refresh call fails because there's a successful call by another process that starts before $t_0$ and ends before $t_1$. Any other successful calls by other processes after that must end after $t_1$ because of our assumption. However, then, the second call must have been successful because it starts after the first failed call and ends before $t_1$ and in this timespan, no other refresh calls is running. Therefore, by contradiction, $(*)$ holds.

  Using $(*)$, there exists a successful $n$-refresh call between $t_0$ and $t_1$.

  Consider one such successful refresh between $t_0$ and $t_1$. Suppose it succeeds at time $t$, where $t_0 lt.eq t lt.eq t_1$.

  If $n$ is a leaf node, the $n$-refresh call is `refreshLeaf(`$n$`)` (@lt-refresh-leaf). Then, applying @possible-ranks-theorem, either $r a n k(n, t)$ is `DUMMY` or $E$, with $E$ being the enqueuer attached to $n$. If $E$'s `min-timestamp` is read at time $t_r$, $t_0 lt.eq t_s lt.eq t$. If `MAX` is read out, $r a n k(n, t_s) = $ `DUMMY`. If some other value is read out, $r a n k(n, t_s) = r a n k(E)$. In both case, $m i n \- t s(r a n k(n, t), t_s) = m i n \- t s(E, t_s)$.

  If $n$ is not a leaf node, the $n$-refresh call is `refresh(`$n$`)` (@lt-refresh). Then, by the way `refresh` is defined, for each child $c$ of $n$, $m i n \- t s(r a n k(n, t), t_s(c)) lt.eq m i n \- t s (r a n k(c, t_r(c)), t_s(c))$. $t_r(c)$ is the time we read the rank stored in $c$ and $t_s(c)$ is the time we read the value of `min-timestamp` stored in the enqueuer of that rank so $t_0 lt.eq t_r(c) lt.eq t_s(c) lt.eq t_1$. Furthermore, by the way `refresh` is defined, there exists a child $c$ of $n$ such that $r a n k(n, t) = r a n k(c, t_r(c))$. By definition, $n$ is consistent at time $t_1$ with respect to time $t_0$.

  We have proved the theorem.
]

#theorem[If `refresh` on a non-leaf node $n$ finishes line 20 at time $t_0$ and finishes successfully at $t_1$. Then, for any node $n in N$, $n$ is consistent at time $t_1$ with respect to time $t_0$.] <refresh-theorem>

#proof[
  By the way `refresh` is defined, for each child $c$ of $n$, $m i n \- t s(r a n k(n, t), t_s(c)) lt.eq m i n \- t s (r a n k(c, t_r(c)), t_s(c))$. $t_r(c)$ is the time we read the rank stored in $c$ and $t_s(c)$ is the time we read the value of `min-timestamp` stored in the enqueuer of that rank so $t_0 lt.eq t_r(c) lt.eq t_s(c) lt.eq t_1$. Furthermore, by the way `refresh` is defined, there exists a child $c$ of $n$ such that $r a n k(n, t) = r a n k(c, t_r(c))$. By definition, $n$ is consistent at time $t_1$ with respect to time $t_0$.
]

#theorem[If there's no `dequeue` happening from $t_0$ to $t_1$, then for any node $n$, $m i n - t s(r a n k(n, t_x), t_y)$ is monotonically decreasing with any $t_x, t_y in [t_0, t_1]$.]

#proof[
  During $t_0$ and $t_1$, only `enqueue`s can run. Therefore, for any rank $r$, $m i n - s p s c - t s(r, t)$ is monotonically decreasing for $t in [t_0, t_1]$. $(1)$

  Due to @one-dequeue-one-enqueue-corollary, for any rank $r$, the only `enqueue` will always succeed in `refreshTimestamp`. Due to $(1)$, $m i n - t s(r, t)$ is also monotonically decreasing for $t in [t_0, t_1]$. $(2)$

  From $(2)$, it's easy to see that for any node $n$, if we fix $t_x$, $m i n - t s(r a n k(n, t_x), t_y)$ is monotonically decreasing with any $t_y in [t_0, t_1]$. $(3)$

  For any leaf node $l$, only one `enqueue` that can modify it at a time. Therefore, the only `enqueue` will always succeed in `refreshLeaf` at $t_(r\-e n d\-0)$. Due to how `refreshLeaf` is defined and due to $(2)$, $m i n - t s(r a n k(l, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_0, t_1]$.

  Consider any non-leaf node $n$.

  Suppose there's a sequence of successful `refresh` calls ending at $t_(r\-e n d\-1) < t_(r\-e n d\-2) < ... < t_(r\-e n d\-k)$. Suppose also they finishes line 20 (@lt-refresh) at $t_(r\-s t a r t\-1)$, $t_(r\-s t a r t\-2)$, ..., $t_(r\-s t a r t\-k)$. Obviously, $t_(r\-e n d\-(i - 1)) lt.eq t_(r\-s t a r t\-i)$, because otherwise, the `CAS` in the `refresh` calls cannot be successful.

  For every child node $c$ of $n$, $t_(r\-i)(c)$ is the time the `i`-th `refresh` reads the rank stored in $c$ and $t_(s\-i)(c)$ is the time it reads the value of `min-timestamp` stored in the enqueuer of that rank. Therefore, $t_(r\-s t a r t\- i) lt.eq t_(r\-i)(c) lt.eq t_(s\-i)(c) lt.eq t_(r\-e n d\-i)$.

  Suppose the theorem already holds for every child node $c$ of $n$. $(4)$

  Applying @refresh-theorem:
  - For any child $c$,
    #linebreak()
    $m i n \- t s(r a n k(n, t_(r\-e n d \- i)), t_(s\-i)(c)) lt.eq m i n \- t s(r a n k(c, t_(r\-i)(c)), t_(s\-i)(c))$. $(5)$
  - There exists a child node $c_i$ of $n$ such that
    #linebreak()
    $r a n k(n, t_(r\-e n d \- i)) = r a n k(c_i, t_(r\-i)(c_i))$. $(6)$

  Combining $(5)$ with $c=c_(i-1)$ in $(6)$, we have
  
  $m i n \- t s(r a n k(n, t_(r\-e n d \- i)), t_(s\-i)(c_(i-1)))
  #linebreak()
  lt.eq m i n \- t s(r a n k(c_(i-1), t_(r\-i)(c_(i-1))), t_(s\-i)(c_(i-1)))$. $(7)$

  Combing $(4)$ with $(7)$,

  $m i n \- t s(r a n k(n, t_(r\-e n d \- i)), t_(s\-i)(c_(i-1)))$
  #linebreak()
  $lt.eq m i n \- t s(r a n k(c_(i-1), t_(r\-i)(c_(i-1))), t_(s\-i)(c_(i-1)))$
  #linebreak()
  $lt.eq m i n \- t s(r a n k(c_(i-1), t_(r\-(i-1))(c_(i-1))), t_(s\-(i-1))(c_(i-1)))$ $= m i n \- t s(r a n k(n, t_(r\-e n d \- (i-1))), t_(s\-(i-1))(c_(i-1)))$.

  So after every `refresh`, $m i n \- t s(r a n k(n, t_x), t_y)$ can only decrease. The theorem therefore holds.
]

#theorem[If an `enqueue` $e$ obtains a timestamp $c$ and finishes at time $t_0$ and is still *unmatched* at time $t_1$, we have $m i n \- s p s c \- t s(r a n k(r o o t, t), t) lt.eq c$ for every $t$ such that $t_0 lt.eq t < t_1$ and $t$ is not within a `dequeue`.]

#proof[
  We take $r_e$ to be the rank of enqueuer $e$.

  Suppose the item with timestamp $c$ is enqueued at time $t_(e n q u e u e)$. Because $e$ is unmatched up until $t_1$, $c$ is always in the local SPSC from $t_(e n q u e u e)$ to $t_1$. In other words, $m i n \- t s(r_e, t) lt.eq c$ for any $t$ that $t_(e n q u e u e) lt.eq t lt.eq t_1$. $(1)$

  We consider $e$'s propagation process (@lt-propagate).

  Suppose the two `refreshTimestamp` calls on line 10-11 start at $t_(t s \_ s t a r t) lt.eq t_(e n q u e u e)$ and end at $t_(t s \_ e n d)$.
  - If one of the two succeeds, due to $(1)$, $m i n \- t s(r_e, t) lt.eq c$ for any $t$ that $t_(t s \_ e n d) lt.eq t lt.eq t_1$.
  - If both fail, following the same reasoning in a previous theorem, there must be some other successful `refreshTimestamp` on the same node starts after $t_(t s \_ s t a r t)$ and ends before $t_(t s \_ e n d)$. Due to $(1)$, $m i n \- t s(r_e, t) lt.eq c$ for any $t$ that $t_(t s \_ e n d) lt.eq t lt.eq t_1$.
  Therefore, $m i n \- t s(r_e, t) lt.eq c$ for any $t$ that $t_(t s \_ e n d) lt.eq t lt.eq t_1$. $(2)$

  Suppose the two `refreshLeaf` calls on the leaf node $n_0$ on line 12-13 start at $t_(0 \- s t a r t)$ and end at $t_(0 \- e n d)$. Applying @possible-ranks-theorem, the leaf node $n_0$ can only store `DUMMY` rank or $r_e$.
  - If one of the two refresh calls succeeds, due to $(2)$, $r a n k(n_0, t) eq.not$ `DUMMY` for any $t$ that $t_(0 \- e n d) lt.eq t lt.eq t_1$. In other words, $r a n k(n_0, t) eq r_e$ for any $t$ that $t_(0 \- e n d) lt.eq t lt.eq t_1$.
  - If both fail, following the same reasoning in a previous theorem, there must be some other successful `refreshLeaf` on the same node starts after $t_(0 \- s t a r t)$ and ends before $t_(0 \- e n d)$. Similarly, we can obtain $r a n k(n_0, t) eq r_e$ for any $t$ that $t_(0 \- e n d) lt.eq t lt.eq t_1$.
  Therefore, $r a n k(n_0, t) eq r_e$ for any $t$ that $t_(0 \- e n d) lt.eq t lt.eq t_1$. Or due to $(2)$, $m i n \- t s(r a n k(n_0, t), t) lt.eq c$ for any $t$ that $t_(0 \- e n d) lt.eq t lt.eq t_1$. $(3)$

  Consider all the non-leaf nodes $n_i in p a t h(e)$, $i gt.eq 1$, with $n_i$ being the parent of $n_(i - 1)$. Suppose the two `refresh` calls on line 17-18 start at $t_(i \- s t a r t)$ and end at $t_(i \- e n d)$ $(4)$. We will prove by induction that $m i n \- t s(r a n k(n_i, t), t) lt.eq c$ for any $t$ that $t_(i \- e n d) lt.eq t lt.eq t_1$ and if at $t$ there's a `dequeue` $d$ such that $n_i in p a t h(d)$, $t$ must be after $d$'s call to `refresh(`$n_i$`)`. $(*)$

  $(*)$ already holds for $i = 0$.

  Suppose $(*)$ holds for $i = k - 1$, in other words, $m i n \- t s(r a n k(n_(k-1), t), t) lt.eq c$ for any $t$ that $t_((k-1) \- e n d) lt.eq t lt.eq t_1$ and if at $t$ there's a `dequeue` $d$ such that $n_(k-1) in p a t h(d)$, $t$ must be after $d$'s call to `refresh(`$n_(k-1)$`)`. $(4)$

  We will prove that $(*)$ also holds for $i = k$, in other words, $m i n \- t s(r a n k(n_k, t), t) lt.eq c$ for any $t$ that $t_(k \- e n d) lt.eq t lt.eq t_1$ and if at $t$ there's a `dequeue` $d$ such that $n_k in p a t h(d)$, $t$ must be after $d$'s call to `refresh(`$n_k$`)`.

  First case: $t_(k \- e n d)$ is either not in a `dequeue` $d$ such that $n_k in p a t h(d)$ or is after $d$'s call to `refresh(`$n_k$`)`. Applying @refresh-retry-theorem, we have $n_k$ is consistent at $t_(k \- e n d)$ with respect to $t_(k \- s t a r t)$. This means, there exists $t_k$ and $t_(k-1)$, with $t_(k \- s t a r t) lt.eq t_k, t_(k-1) lt.eq t_(k \- e n d)$, such that $m i n \- t s(r a n k(n_k, t_(k \- e n d)), t_k) lt.eq m i n \- t s(r a n k(n_(k-1), t_(k-1)), t_(k-1))$.
]

#theorem[An `enqueue` $e$ will eventually be matched with a `dequeue` $d$ if there's an infinite sequence of `dequeue`s.]

#theorem[An `enqueue` $e$ can only be matched by a `dequeue` $d$ that overlaps or succeeds $e$.]

#theorem[If an `enqueue` $e_0$ precedes another `enqueue` $e_1$, $e_0$ will be matched before $e_1$ if there's an infinite sequence of `dequeue`s.]

#theorem[If a `dequeue` $d_0$ precedes another `dequeue` $d_1$, if $d_0$ matches $e_0$ and $d_1$ matches $e_1$ then either $e_0$ overlaps with $e_1$ or $e_0$ precedes $e_1$.]

#theorem[If a `dequeue` $d$ precedes another `enqueue` $e$, $d$ will never be matched with $e$.]

== Memory safety

== Wait-freedom

#bibliography("/bibliography.yml", title: [References])
