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

The structure of LTQueue is modified as in @modified-ltqueue-tree. At the bottom nodes (represented by the type `enqueuer_t`), besides the local SPSC, the minimum-timestamp within the SPSC is also stored. The internal nodes no longer store a timestamp but a rank of an enqueuer. This rank corresponds to the enqueuer with the minimum timestamp among the node's children's ranks. Note that if a local SPSC is empty, the minimum-timestamp of the corresponding bottom node is set to `MAX` and its leaf node's rank is set to a `DUMMY` rank.

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
)

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
)

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
)

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
)

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
)

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
)

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

#definition[A *history* is a set of well-formed *method calls*.]

#definition[An extension of *history* $H$ is a *history* $H'$ such that any method call with $bot$ response event is replaced by a valid response event.]

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

We starts with some assumptions:
- We have constructed a modified LTQueue with $n$ enqueuers.
- The modified LTQueue is in its initial state at time $t = 0$.

We consider the state of the modified LTQueue over a timeline starting at $t = 0$.

#definition[For an enqueuer $E$, the timestamp of the first element in $E$'s local SPSC (among the elements between `First` and `Last`) at time $t_0$ is denoted as $m i n\- s p s c \-t s(E, t_0)$.]

#theorem[If an enqueuer $E$ invokes `spsc_readFront`#sub[`e`] (@spsc-enqueuer-readFront) at time $t_0$, then it returns an item with a timestamp $t s_0$ such that $t s_0 lt.eq m i n\- s p s c \-t s(E, t_1)$ for some $t_1 gt.eq t_0$.]

#proof[
  In this proof, in the procedure `spsc_dequeue` (@spsc-dequeue), we say an _item dequeue_ happens on line 17.

  In $E$'s local SPSC, only $E$ and another dequeuer can modify the SPSC.

  If the dequeuer doesn't run during $t_0$ until the end of `spsc_readFront`#sub[`e`], then it's trivial that this is true.

  If an `spsc_dequeue` overlaps with this timestamp, then there's three possibilities:
  1. $bot$ is returned.
    - If $bot$ is returned before the _item dequeue_, at the end of `spsc_dequeue` which is at time $t_1 gt.eq t_0$, $M A X = m i n\-s p s c \- t s (E, t_1)$.
    - If $bot$ is returned at time $t_1 gt.eq t_0$, after the _item dequeue_, it's easy to see that $M A X = m i n\-s p s c \- t s (E, t_1)$.
  2. `Help` is returned (line 10 in @spsc-enqueuer-readFront). In this case, between line 6 and line 9 of @spsc-enqueuer-readFront, an _item dequeue_ has happened at time $t_1$ and put the item in `Help`, so of course, `Help`'s timestamp would be $ lt.eq m i n\- s p s c \-t s(E, t_1)$. Because the _item dequeue_ happens after line 6, $t_1 gt.eq t_0$. Therefore, the theorem holds.
  3. `tmp.val` is returned (line 11 in @spsc-enqueuer-readFront). In this case, an _item dequeue_ hasn't been performed yet between line 6 and line 9 of @spsc-enqueuer-readFront. Therefore, after the _item dequeue_ has actually happened at time $t_1 gt.eq t_0$, the new minimum timestamp of the local SPSC would be of course greater than the returned timestamp, so the theorem holds.
]

#theorem[If the dequeuer invokes `spsc_readFront`#sub[`d`] (@spsc-dequeuer-readFront) at time $t_0$, then it returns an item with a timestamp $t s_0$ such that $t s_0 lt.eq m i n\- s p s c \-t s(E, t_1)$ for some $t_1 gt.eq t_0$.]

#proof[
  In an enqueuer $E$'s local SPSC, only $E$ and another dequeuer can modify the SPSC.

  If the enqueuer $E$ doesn't run during $t_0$ until the end of `spsc_readFront`#sub[`e`], then it's trivial that this is true.

  If the SPSC isn't empty at $t_0$, obviously the theorem holds true as an enqueuer cannot modify the minimum timestamp of the local SPSC if it's not empty.

  If the SPSC is empty at $t_0$, there are two possibilities:
  1. $bot$ is returned at time $t_1 gt.eq t_0$. This means the enqueuer $E$ hasn't updated `Last` yet (line 5 of @spsc-enqueue) at time $t_1$. This means $M A X = m i n\- s p s c \-t s(E, t_1)$
  2. Some value other than $bot$ is returned at time $t_1$. This means this value must be the first item in the SPSC. Therefore, the theorem holds.
]

#definition[For an enqueuer $E$, the value of the `min-timestamp` variable stored in $E$'s enqueuer node at time $t_0$ is denoted as $m i n \- t s(E, t_0)$.]

#definition[For a tree node $n o d e$, the rank stored in $n o d e$ at time $t_0$ is denoted as $r a n k (n o d e, t_0)$.]

== Memory safety

== Wait-freedom

#bibliography("/bibliography.yml", title: [References])
