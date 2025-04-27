= Theoretical aspects <theoretical-aspects>

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

This section discusses the correctness and progress guarantee properties of the distributed MPSC queue algorithms introduced in @distributed-queues[]. We also provide a theoretical performance model of these algorithms to predict how well they scale to multiple nodes.

== Terminology

In this section, we introduce some terminology that we will use throughout our proofs.

#definition[In an SPSC/MPSC queue, an enqueue operation $e$ is said to *match* a dequeue operation $d$ if $d$ returns the value that $e$ enqueues. Similarly, $d$ is said to *match* $e$. In this case, both $e$ and $d$ are said to be *matched*.]

#definition[In an SPSC/MPSC queue, an enqueue operation $e$ is said to be *unmatched* if no dequeue operation *matches* it.]

#definition[In an SPSC/MPSC queue, a dequeue operation $d$ is said to be *unmatched* if no enqueue operation *matches* it, in other word, $d$ returns `false`.]

== Preliminaries

In this section, we formalize the notion of correct concurrent algorithms and harmless ABA problem. We will base our proofs on these formalisms to prove their correctness. We also provide a simple way to theoretically model our queues' performance.

=== Linearizability

Linearizability is a criteria for evaluating a concurrent algorithm's correctness. This is the model we use to prove our algorithm's correctness. Our formalization of linearizability is equivalent to that of @art-of-multiprocessor-programming by Herlihy and Shavit. However, there are some differences in our terminology.

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

Now that we have formalized the way to describe the order of events via *histories*, we can now formalize the mechanism to determine if a *history* is valid. The easier case is for a *sequential history*.

#definition[For a concurrent object $S$, a *sequential specification* of $S$ is a function that either returns `true` (valid) or `false` (invalid) for a *sequential history* $H$.]

The harder case is handled via the notion of *linearizable*.

#definition[A history $H$ on a concurrent object $S$ is *linearizable* if it has an extension $H'$ and there exists a _sequential history_ $H_S$ such that:
  1. The *sequential specification* of $S$ accepts $H_S$.
  2. There exists a one-to-one mapping $M$ of a method call $(i, r) in H'$ to a method call $(i_S, r_S) in H_S$ with the properties that:
    - $i$ must be the same as $i_S$ except for the timestamp.
    - $r$ must be the same $r_S$ except for the timestamp or $r$.
  3. For any two method calls $X$ and $Y$ in $H'$, #linebreak() $X ->$#sub($H'$)$Y => $ $M(X) ->$#sub($H_S$)$M(Y)$.
]

We consider a history to be valid if it's linearizable.

==== Linearizable SPSC

Our SPSC supports 3 methods:
- `enqueue` which accepts an input parameter and returns a boolean.
- `dequeue` which accepts an output parameter and returns a boolean.
- `readFront` which accepts an output parameter and returns a boolean.

#definition[An SPSC is *linearizable* if and only if any history produced from the SPSC that does not have overlapping dequeue method calls and overlapping enqueue method calls is _linearizable_ according to the following _sequential specification_:
  - An enqueue can only be matched by one dequeue.
  - A dequeue can only be matched by one enqueue.
  - The order of item dequeues is the same as the order of item enqueues.
  - An enqueue can only be matched by a later dequeue.
  - A dequeue returns `false` when the queue is empty.
  - A dequeue returns `true` and matches an enqueue when the queue is not empty.
  - An enqueue returns `false` when the queue is full.
  - An enqueue would return `true` when the queue is not full and the number of elements should increase by one.
  - A read-front would return `false` when the queue is empty.
  - A read-front would return `true` and the first element in the queue is read out.
] <linearizable-spsc>

==== Linearizable MPSC queue

An MPSC queue supports 2 methods:
- `enqueue` which accepts an input parameter and returns a boolean.
- `dequeue` which accepts an output parameter and returns a boolean.

#definition[An MPSC queue is *linearizable* if and only if any history produced from the MPSC queue that does not have overlapping dequeue method calls is _linearizable_ according to the following _sequential specification_:
  - An enqueue can only be matched by one dequeue.
  - A dequeue can only be matched by one enqueue.
  - The order of item dequeues is the same as the order of item enqueues.
  - An enqueue can only be matched by a later dequeue.
  - A dequeue returns `false` when the queue is empty.
  - A dequeue returns `true` and matches an enqueue when the queue is not empty
  - An enqueue that returns `true` will be matched if there are enough dequeues after that.
  - An enqueue that returns `false` will never be matched.
] <linearizable-mpsc>

=== ABA-safety <ABA-safety>

Not every ABA problem is unsafe. We formalize in this section which ABA problem is safe and which is not.

#definition[A *modification instruction* on a variable `v` is an atomic instruction that may change the value of `v` e.g. a store or a CAS.]

#definition[A *successful modification instruction* on a variable `v` is an atomic instruction that changes the value of `v` e.g. a store or a successful CAS.]

#definition[A *CAS-sequence* on a variable `v` is a sequence of instructions of a method $m$ such that:
  - The first instruction is a load $v_0 = $ `load(`$v$`)`.
  - The last instruction is a `CAS(&`$v$`,`$v_0$`,`$v_1$`)`.
  - There's no modification instruction on `v` between the first and the last instruction.
]

#definition[A *successful CAS-sequence* on a variable `v` is a *CAS-sequence* on `v` that ends with a successful CAS.]

#definition[Consider a method $m$ on a concurrent object $S$. $m$ is said to be *ABA-safe* if and only if for any history of method calls produced from $S$, we can reorder any successful CAS-sequences inside an invocation of $m$ in the following fashion:
  - If a successful CAS-sequence is part of an invocation of $m$, after reordering, it must still be part of that invocation.
  - If a successful CAS-sequence by an invocation of $m$ precedes another by that invocation, after reordering, this ordering is still respected.
  - Any successful CAS-sequence by an invocation of $m$ after reordering must not overlap with a successful modification instruction on the same variable.
  - After reordering, all method calls' response events on the concurrent object $S$ stay the same.
]

=== Performance model

We use a simple performance model, inspiring by the big-O notation for worst-case time complexity. Specifically, we model the latency of a operation by counting the number of remote operations and local operations taken by that operation. This model is simple but sufficient, as our two new algorithms are wait-free, which ensures that the worst-case time complexity of them cannot be infinite.

== Theoretical proofs of the distributed SPSC

In this section, we focus on the correctness and progress guarantee of the simple distributed SPSC established in @distributed-spsc.

=== Correctness

==== ABA problem

There's no CAS instruction in our simple distributed SPSC, so there's no potential for ABA problem.

==== Memory reclamation

There's no dynamic memory allocation and deallocation in our simple distributed SPSC, so it is memory-safe.

==== Linearizability

We prove that our simple distributed SPSC is linearizable.

#theorem(
  name: "Linearizability of the simple distributed SPSC",
)[The distributed SPSC given in @distributed-spsc is linearizable.] <spsc-linearizability-theorem>

#proof[
  We claim that the following are the linearization points of our SPSC's methods:
  - The linearization point of an `spsc_enqueue` call (@spsc-enqueue) that returns `false` is line 3.
  - The linearization point of an `spsc_enqueue` call (@spsc-enqueue) that returns `true` is line 7.
  - The linearization point of an `spsc_dequeue` call (@spsc-dequeue) that returns `false` is line 17.
  - The linearization point of an `spsc_dequeue` call (@spsc-dequeue) that returns `true` is line 21.
  - The linearization point of `spsc_readFront`#sub(`e`) call (@spsc-enqueue-readFront) that returns `false` is line 10 or line 12 if line 10 is passed.
  - The linearization point of `spsc_readFront`#sub(`e`) call (@spsc-enqueue-readFront) that returns `true` is line 12.
  - The linearization point of `spsc_readFront`#sub(`d`) call (@spsc-dequeue-readFront) that returns `false` is line 25.
  - The linearization point of `spsc_readFront`#sub(`d`) call (@spsc-dequeue-readFront) that returns `true` is right after line 25 (or right before line 28 if line 25 is never executed).

  We define a total ordering $<$ on the set of completed method calls based on these linearization points: If the linearization point of a method call $A$ is before the linearization point of a method call $B$, then $A < B$.

  If the distributed SPSC is linearizable, $<$ would define a equivalent valid sequential execution order for our SPSC method calls.

  A valid sequential execution of SPSC method calls would possess the following characteristics.

  _An enqueue can only be matched by one dequeue_: Each time an `spsc_dequeue` is executed, it advances the `First` index. Because only one dequeue can happen at a time, it's guaranteed that each dequeue proceeds with one unique `First` index. Two dequeues can only dequeue out the same entry in the SPSC's array if their `First` indices are congurent modulo `Capacity`. However, by then, this entry must have been overwritten. Therefore, an enqueue can only be dequeued at most once.

  _A dequeue can only be matched by one enqueue_: This is trivial, as based on how @spsc-dequeue is defined, a dequeue can only dequeue out at most one value.

  _The order of item dequeues is the same as the order of item enqueues_: To put more precisely, if there are 2 `spsc_enqueue`s $e_1$, $e_2$ such that $e_1 < e_2$, then either $e_2$ is unmatched or $e_1$ matches $d_1$ and $e_2$ matches $d_2$ such that $d_1 < d_2$. If $e_2$ is unmatched, the statement holds. Suppose $e_2$ matches $d_2$. Because $e_1 < e_2$, based on how @spsc-enqueue is defined, $e_1$ corresponds to a value $i_1$ of `Last` and $e_2$ corresponds to a value $i_2$ of `Last` such that $i_1 < i_2$. Based on how @spsc-dequeue is defined, each time a dequeue happens successfully, `First` would be incremented. Therefore, for $e_2$ to be matched, $e_1$ must be matched first because `First` must surpass $i_1$ before getting to $i_2$. In other words, $e_1$ matches $d_1$ such that $d_1 < d_2$.

  _An enqueue can only be matched by a later dequeue_: To put more precisely, if an `spsc_enqueue` $e$ matches an `spsc_dequeue` $d$, then $e < d$. If $e$ hasn't executed its linearization point at line 7, there's no way $d$'s line 20 can see $e$'s value. Therefore, $d$'s linearization point at line 21 must be after $e$'s linearization point at line 7. Therefore, $e < d$.

  _A dequeue would return `false` when the queue is empty_: To put more precisely, for an `spsc_dequeue` $d$, if by $d$'s linearization point, every successful `spsc_enqueue` $e'$ such that $e' < d$ has been matched by $d'$ such that $d' < d$, then $d$ would be unmatched and return `false`. By this assumption, any `spsc_enqueue` $e$ that has executed its linearization point at line 7 before $d$'s line 16 has been matched. Therefore, `First = Last` at line 16, or `First >= Last_buf`, therefore, the if condition at line 16-19 is entered. Also by the assumption, any `spsc_enqueue` $e$ that has executed its linearization point at line 7 before $d$'s line 18 has been matched. Therefore, `First = Last` at line 18. Then, line 19 is executed and $d$ returns `false`.

  _A dequeue would return `true` and match an enqueue when the queue is not empty_: To put more precisely, for an `spsc_dequeue` $d$, if there exists a successful `spsc_enqueue` $e'$ such that $e' < d$ and has not been matched by a dequeue $d'$ such that $d' < e'$, then $d$ would be match some $e$ and return `true`. By this assumption, some $e'$ must have executed its linearization point at line 7 but is still unmatched by the time $d$ starts. Then, `First < Last`, so $d$ must match some enqueue $e$ and returns `true`.

  _An enqueue would return `false` when the queue is full_: To put more precisely, for an `spsc_enqueue` $e$, if by $e$'s linearization point, the number of unmatched successful `spsc_enqueue` $e' < e$ by the time $e$ starts equals `Capacity`, then $e$ returns `false`. By this assumption, any $d'$ that matches $e'$ must satisfy $e < d'$, or $d'$ must execute its synchronization point at line 21 after line 1 and line 4 of $e$, then $e$'s line 5 must have executed and return `false`.

  _An enqueue would return `true` when the queue is not full and the number of elements should increase by one_: To put more precisely, for an `spsc_enqueue` $e$, if by $e$'s linearization point, the number of unmatched successful `spsc_enqueue` $e' < e$ by the time $e$ starts is fewer than `Capacity`, then $e$ returns `true`. By this assumption, `First < Last` at least until $e$'s linearization point and because line 7 must be executed, which means the number of elements should increase by one.

  _A read-front would return `false` when the queue is empty_: To put more precisely, for a read-front $r$, if by $r$'s linearization point, every successful `spsc_enqueue` $e'$ such that $e' < r$ has been matched by $d'$ such that $d' < d$, then $r$ would return `false`. That means any unmatched successful `spsc_enqueue` $e$ must have executed its linearization point at line 7 after $r$'s, or `First = Tail` before $r$'s linearization point
  - For an enqueuer's read-front, if $r$ doesn't pass line 10, the statement holds. If $r$ passes line 10, by the assumption, $r$ would execute line 14, because $r$ sees that `First = Tail`.
  - For an dequeuer's read-front, $r$ must enter line 25-27 because `First_buf = Tail_buf`, due to from the dequeuer's point of view, `First_buf = First` and `Last_buf <= Last`. Similarly, $r$ must execute line 27 and return `false`.

  _A read-front would return `true` and the first element in the queue is read out_: To put more precisely, for a read-front $r$, if before $r$'s linearization point, there exists some unmatched successful `spsc_enqueue` $e'$ such that $e' < r$, then $r$ would read out the same value as the first $d$ such that $r < d$. By this assumption, any $d'$ that matches some of these successful `spsc_enqueue` $e'$ must execute its linearization point at line 21 after $r$'s linearization point. Therefore, `First < Last` until $r$'s linearization point.
  - For an enqueuer's read-front, $r$ must not execute line 11 and line 14. Therefore, line 15 is executed, and `First_buf` at this point is the same as `First_buf` of the first $d$ such that $r < d$, because we have just read it at line 12, and any successful $d' > r$ must execute line 21 after line 15, therefore, `First` has no chance to be incremented between line 12 and line 15.
  - For a dequeuer's read-front, $r$ must not execute line 25-27 and execute line 28 instead. It's trivial that $r$ reads out the same value as the first dequeue $d$ such that $r < d$ because there can only be one dequeuer.

  In conclusion, for any completed history of method calls our SPSC can produce, we have defined a way to sequentially order them in a way that conforms to SPSC's sequential specification. By @linearizable-spsc, our SPSC is linearizable.
]

=== Progress guarantee

Our simple distributed SPSC is wait-free:
- `spsc_dequeue` (@spsc-dequeue) does not execute any loops or wait for any other method calls.
- `spsc_enqueue` (@spsc-enqueue) does not execute any loops or wait for any other method calls.
- `spsc_readFront`#sub(`e`) (@spsc-enqueue-readFront) does not execute any loops or wait for any other method calls.
- `spsc_readFront`#sub(`d`) (@spsc-dequeue-readFront) does not execute any loops or wait for any other method calls.

=== Performance model

== Theoretical proofs of dLTQueue

In this section, we provide proofs covering all of our interested theoretical aspects in dLTQueue.

=== Proof-specific notations

The structure of dLTQueue is presented again in @remind-modified-ltqueue-tree.

As a reminder, the bottom rectangular nodes are called the *enqueuer nodes* and the circular node are called the *tree nodes*. Tree nodes that are attached to an enqueuer node are called *leaf nodes*, otherwise, they are called *internal nodes*. Each *enqueuer node* is hosted on the enqueuer that corresponds to it. The enqueuer nodes accomodate an instance of our distributed SPSC in @distributed-spsc and a `Min_timestamp` variable representing the minimum timestamp inside the SPSC. Each *tree node* stores a rank of a enqueuer that's attached to the subtree which roots at the *tree node*.

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
    ) <remind-modified-ltqueue-tree>
  ],
)

We will refer `propagate`#sub(`e`) and `propagate`#sub(`d`) as `propagate` if there's no need for discrimination. Similarly, we will sometimes refer to `refreshNode`#sub(`e`) and `refreshNode`#sub(`d`) as `refreshNode`, `refreshLeaf`#sub(`e`) and `refreshLeaf`#sub(`d`) as `refreshLeaf`, `refreshTimestamp`#sub(`e`) and `refreshTimestamp`#sub(`d`) as `refreshTimestamp`.

#definition[For a tree node $n$, the rank stored in $n$ at time $t$ is denoted as $r a n k(n, t)$.]

#definition[For an enqueue or a dequeue $op$, the rank of the enqueuer it affects is denoted as $r a n k(op)$.]

#definition[For an enqueuer whose rank is $r$, the `Min_timestamp` value stored in its enqueuer node at time $t$ is denoted as $m i n \- t s(r, t)$. If $r$ is `DUMMY_RANK`, $m i n \- t s(r, t)$ is `MAX_TIMESTAMP`.]

#definition[For an enqueuer with rank $r$, the minimum timestamp among the elements between `First` and `Last` in its SPSC at time $t$ is denoted as $m i n \- s p s c \- t s(r, t)$. If $r$ is dummy, $m i n \- s p s c \- t s(r, t)$ is `MAX`.]

#definition[For an enqueue or a dequeue $op$, the set of nodes that it calls `refreshNode` (@ltqueue-enqueue-refresh-node or @ltqueue-dequeue-refresh-node) or `refreshLeaf` (@ltqueue-enqueue-refresh-leaf or @ltqueue-dequeue-refresh-leaf) on is denoted as $p a t h(op)$.]

#definition[For an enqueue or a dequeue, *timestamp-refresh phase* refer to its execution of line 18-19 in `propagate`#sub(`e`) (@ltqueue-enqueue-propagate) or line 71-72 in `propagate`#sub(`d`) (@ltqueue-dequeue-propagate).]

#definition[For an enqueue $op$, and a node $n in p a t h(op)$, *node-$n$-refresh phase* refer to its execution of:
  - Line 20-21 of `propagate`#sub(`e`) (@ltqueue-enqueue-propagate) if $n$ is a leaf node.
  - Line 25-26 of `propagate`#sub(`e`) (@ltqueue-enqueue-propagate) to refresh $n$'s rank if $n$ is a non-leaf node.]

#definition[For a dequeue $op$, and a node $n in p a t h(op)$, *node-$n$-refresh phase* refer to its execution of:
  - Line 73-74 of `propagate`#sub(`d`) (@ltqueue-dequeue-propagate) if $n$ is a leaf node.
  - Line 78-79 of `propagate`#sub(`d`) (@ltqueue-dequeue-propagate) to refresh $n$'s rank if $n$ is a non-leaf node.]

#definition[`refreshTimestamp`#sub(`e`) (@ltqueue-enqueue-refresh-timestamp) is said to start its *CAS-sequence* if it finishes line 29. `refreshTimestamp`#sub(`e`) is said to end its *CAS-sequence* if it finishes line 34 or line 36.]

#definition[`refreshTimestamp`#sub(`d`) (@ltqueue-dequeue-refresh-timestamp) is said to start its *CAS-sequence* if it finishes line 83. `refreshTimestamp`#sub(`d`) is said to end its *CAS-sequence* if it finishes line 88 or line 90.]

#definition[`refreshNode`#sub(`e`) (@ltqueue-enqueue-refresh-node) is said to start its *CAS-sequence* if it finishes line 38. `refreshNode`#sub(`e`) is said to end its *CAS-sequence* if it finishes line 52.]

#definition[`refreshNode`#sub(`d`) (@ltqueue-dequeue-refresh-node) is said to start its *CAS-sequence* if it finishes line 92. `refreshNode`#sub(`d`) is said to end its *CAS-sequence* if it finishes line 106.]

#definition[`refreshLeaf`#sub(`e`) (@ltqueue-enqueue-refresh-leaf) is said to start its *CAS-sequence* if it finishes line 55. `refreshLeaf`#sub(`e`) is said to end its *CAS-sequence* if it finishes line 60.]

#definition[`refreshLeaf`#sub(`d`) (@ltqueue-dequeue-refresh-leaf) is said to start its *CAS-sequence* if it finishes line 109. `refreshLeaf`#sub(`d`) is said to end its *CAS-sequence* if it finishes line 114.]

=== Correctness

==== ABA problem

We use CAS instructions on:
- Line 34 and line 36 of `refreshTimestamp`#sub(`e`) (@ltqueue-enqueue-refresh-timestamp).
- Line 52 of `refreshNode`#sub(`e`) (@ltqueue-enqueue-refresh-node).
- Line 60 of `refreshLeaf`#sub(`e`) (@ltqueue-enqueue-refresh-leaf).
- Line 88 and line 90 of `refreshTimestamp`#sub(`d`) (@ltqueue-dequeue-refresh-timestamp).
- Line 106 of `refreshNode`#sub(`d`) (@ltqueue-dequeue-refresh-node).
- Line 114 of `refreshLeaf`#sub(`e`) (@ltqueue-dequeue-refresh-leaf).

Notice that at these locations, we increase the associated version tags of the CAS-ed values. These version tags are 32-bit in size, therefore, practically, ABA problem can't virtually occur. It's safe to assume that there's no ABA problem in dLTQueue.

==== Memory reclamation

Notice that Slotqueue pushes the memory reclamation problem to the underlying SPSC. Because the underlying SPSC is memory-safe, Slotqueue is also memory-safe.

==== Linearizability

#theorem[In dLTQueue, an enqueue can only match at most one dequeue.] <ltqueue-unique-match-enqueue>

#proof[A dequeue indirectly performs a value dequeue through `spsc_dequeue`. Because `spsc_dequeue` can only match one `spsc_enqueue` by another enqueue, the theorem holds.]

#theorem[In dLTQueue, a dequeue can only match at most one enqueue.] <ltqueue-unique-match-dequeue>

#proof[This is trivial as a dequeue can only read out at most one value, so it can only match at most one enqueue.]

#theorem[Only the dequeuer and one enqueuer can operate on an enqueuer node.]

#proof[This is trivial based on how the algorithm is defined.]

We immediately obtain the following result.

#corollary[Only one dequeue operation and one enqueue operation can operate concurrently on an enqueuer node.] <ltqueue-one-dequeue-one-enqueue-corollary>

#theorem[The SPSC at an enqueuer node contains items with increasing timestamps.] <ltqueue-increasing-timestamp-theorem>

#proof[
  Each enqueue would `FAA` the distributed counter (line 14 in @ltqueue-enqueue) and enqueue into the SPSC an item with the timestamp obtained from that counter. Applying @ltqueue-one-dequeue-one-enqueue-corollary, we know that items are enqueued one at a time into the SPSC. Therefore, later items are enqueued by later enqueues, which obtain increasing values by `FAA`-ing the shared counter. The theorem holds.
]

#theorem[For an enqueue or a dequeue $op$, if $op$ modifies an enqueuer node and this enqueuer node is attached to a leaf node $l$, then $p a t h(op)$ is the set of nodes lying on the path from $l$ to the root node.]

#proof[This is trivial considering how `propagate`#sub(`e`) (@ltqueue-enqueue-propagate) and `propagate`#sub(`d`) (@ltqueue-dequeue-propagate) work.]

#theorem[For any time $t$ and a node $n$, $r a n k(n, t)$ can only be `DUMMY_RANK` or the rank of an enqueuer that's attached to the subtree rooted at $n$.] <ltqueue-possible-ranks-theorem>

#proof[This is trivial considering how `refreshNode`#sub(`e`), `refreshNode`#sub(`d`) and `refreshLeaf`#sub(`e`), `refreshLeaf`#sub(`d`) works.]

#theorem[If an enqueue or a dequeue $op$ begins its *timestamp-refresh phase* at $t_0$ and finishes at time $t_1$, there's always at least one successful call to `refreshTimestamp`#sub(`e`) (@ltqueue-enqueue-refresh-timestamp) or `refreshTimestamp`#sub(`d`) (@ltqueue-dequeue-refresh-timestamp) that affects the enqueuer node corresponding to $r a n k(op)$ and this successful call starts and ends its *CAS-sequence* between $t_0$ and $t_1$.] <ltqueue-refresh-timestamp-theorem>

#proof[
  Suppose the interested *timestamp-refresh phase* affects the enqueuer node $n$.

  Notice that the *timestamp-refresh phase* of both enqueue and dequeue consists of at most 2 `refreshTimestamp` calls affecting $n$.

  If one of the two `refreshTimestamp`s of the *timestamp-refresh phase* succeeds, then the theorem obviously holds.

  Consider the case where both fail.

  The first `refreshTimestamp` fails because there's another `refreshTimestamp` on $n$ ending its *CAS-sequence* successfully after $t_0$ but before the end of the first `refreshTimestamp`'s *CAS-sequence*.

  The second `refreshTimestamp` fails because there's another `refreshTimestamp` on $n$ ending its *CAS-sequence* successfully after $t_0$ but before the end of the second `refreshTimestamp`'s *CAS-sequence*. This another `refreshTimestamp` must start its *CAS-sequence* after the end of the first successful `refreshTimestamp`, otherwise, it would overlap with the *CAS-sequence* of the first successful `refreshTimestamp`, but successful *CAS-sequences* on the same enqueuer node cannot overlap as ABA problem does not occur. In other words, this another `refreshTimestamp` starts and successfully ends its *CAS-sequence* between $t_0$ and $t_1$.

  We have proved the theorem.
]

#theorem[If an enqueue or a dequeue begins its *node-$n$-refresh phase* at $t_0$ and finishes at $t_1$, there's always at least one successful `refreshNode` or `refreshLeaf` calls affecting $n$ and this successful call starts and ends its *CAS-sequence* between $t_0$ and $t_1$.] <ltqueue-refresh-node-theorem>

#proof[This is similar to the above proof.]

#theorem[Consider a node $n$. If within $t_0$ and $t_1$, any dequeue $d$ where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*, then $m i n \- t s(r a n k(n, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_0, t_1]$ .] <ltqueue-monotonic-theorem>

#proof[
  We have the assumption that within $t_0$ and $t_1$, all dequeue where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*. Notice that if $n$ satisfies this assumption, any child of $n$ also satisfies this assumption.

  We will prove a stronger version of this theorem: Given a node $n$, time $t_0$ and $t_1$ such that within $[t_0, t_1]$, any dequeue $d$ where $n in p a t h(d)$ has finished its *node-$n$-refresh phase*. Consider the last dequeue's *node-$n$-refresh phase* before $t_0$ (there maybe none). Take $t_s (n)$ and $t_e (n)$ to be the starting and ending time of the CAS-sequence of the last successful *$n$-refresh call* during this phase, or if there is none, $t_s (n) = t_e (n) = 0$. Then, $m i n \- t s(r a n k(n, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_e (n), t_1]$.

  Consider any enqueuer node of rank $r$ that's attached to a satisfied leaf node. For any $n'$ that is a descendant of $n$, during $t_s (n')$ and $t_1$, there's no call to `spsc_dequeue`. Because:
  - If an `spsc_dequeue` starts between $t_0$ and $t_1$, the dequeue that calls it hasn't finished its *node-$n'$-refresh phase*.
  - If an `spsc_dequeue` starts between $t_s (n')$ and $t_0$, then a dequeue's *node-$n'$-refresh phase* must start after $t_s (n')$ and before $t_0$, but this violates our assumption of $t_s (n')$.
  Therefore, there can only be calls to `spsc_enqueue` during $t_s (n')$ and $t_1$. Thus, $m i n \- s p s c \- t s(r, t_x)$ can only decrease from `MAX_TIMESTAMP` to some timestamp and remain constant for $t_x in [t_s (n'), t_1]$. $(1)$

  Similarly, there can be no dequeue that hasn't finished its *timestamp-refresh phase* during $t_s (n')$ and $t_1$. Therefore, $m i n \- t s (r, t_x)$ can only decrease from `MAX_TIMESTAMP` to some timestamp and remain constant for $t_x in [t_s (n'), t_1]$. $(2)$

  Consider any satisfied leaf node $n_0$. There can't be any dequeue that hasn't finished its *node-$n_0$-refresh phase* during $t_e (n_0)$ and $t_1$. Therefore, any successful `refreshLeaf` affecting $n_0$ during $[t_e (n_0), t_1]$ must be called by an enqueue. Because there's no `spsc_dequeue`, this `refreshLeaf` can only set $r a n k(n_0, t_x)$ from `DUMMY_RANK` to $r$ and this remains $r$ until $t_1$, which is the rank of the enqueuer whose node it's attached to. Therefore, combining with $(1)$, $m i n \- t s(r a n k(n_0, t_x), t_y)$ is monotonically decreasing for $t_x, t_y in [t_e (n_0), t_1]$. $(3)$

  Consider any satisfied non-leaf node $n'$ that is a descendant of $n$. Suppose during $[t_e (n'), t_1]$, we have a sequence of successful *$n'$-refresh calls* that start their CAS-sequences at $t_(s t a r t \- 0) lt t_(s t a r t \- 1) lt t_(s t a r t \- 2) lt ... lt t_(s t a r t \- k)$ and end them at $t_(e n d \- 0) lt t_(e n d \- 1) lt t_(e n d\- 2) lt ... lt t_(e n d \- k)$. By definition, $t_(e n d \- 0) = t_e (n')$ and $t_(s t a r t \- 0) = t_s (n')$. We can prove that $t_(e n d \- i) < t_(s t a r t \- (i+1))$ because successful CAS-sequences cannot overlap.

  Due to how `refreshNode` (@ltqueue-enqueue-refresh-node and @ltqueue-dequeue-refresh-node) is defined, for any $k gt.eq i gt.eq 1$:
  - Suppose $t_(r a n k\-i)(c)$ is the time `refreshNode` reads the rank stored in the child node $c$, so $t_(s t a r t \- i) lt.eq t_(r a n k\-i)(c) lt.eq t_(e n d \- i)$.
  - Suppose $t_(t s\-i)(c)$ is the time `refreshNode` reads the timestamp stored in the enqueuer with the rank read previously, so $t_(s t a r t \- i) lt.eq t_(t s\-i)(c) lt.eq t_(e n d \- i)$.
  - There exists a child $c_i$ such that $r a n k(n', t_(e n d \- i)) = r a n k(c_i, t_(r a n k\-i)(c_i))$. $(4)$
  - For every child $c$ of $n'$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-i)(c)), t_(t s\-i)(c))$. $(5)$

  Suppose the stronger theorem already holds for every child $c$ of $n'$. $(6)$

  For any $i gt.eq 1$, we have $t_e (c) lt.eq t_s (n') lt.eq t_(s t a r t \-(i-1)) lt.eq t_(r a n k\-(i-1))(c) lt.eq t_(e n d \-(i-1)) lt.eq t_(s t a r t \-i) lt.eq t_(r a n k \- i)(c) lt.eq t_1$. Combining with $(5)$, $(6)$, we have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-i)(c)), t_(t s\-i)(c))$ #linebreak() $lt.eq m i n \- t s (r a n k(c, t_(r a n k\-(i-1))(c)), t_(t s\-i)(c))$.

  Choose $c = c_(i-1)$ as in $(4)$. We have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(t s\-i)(c_i))$ #linebreak() $lt.eq m i n \- t s (r a n k(c_(i-1), t_(r a n k\-(i-1))(c_(i-1))),$$ t_(t s\-i)(c_(i-1)))$ #linebreak() $= m i n\- t s(r a n k(n', t_(e n d \- (i-1))), t_(t s \-i)(c_(i-1))$.

  Because $t_(t s \-i)(c_i) lt.eq t_(e n d \- i)$ and $t_(t s \-i)(c_(i-1)) gt.eq t_(e n d \- (i-1))$ and $(2)$, we have for any $k gt.eq i gt.eq 1$, #linebreak() $m i n \- t s(r a n k(n', t_(e n d \- i)), t_(e n d\-i))$ #linebreak() $lt.eq m i n \- t s (r a n k(n', t_(e n d \- (i-1))), t_(e n d \- (i-1)))$. $(*)$

  $r a n k(n', t_x)$ can only change after each successful `refreshNode`, therefore, the sequence of its value is $r a n k(n', t_(e n d \- 0))$, $r a n k(n', t_(e n d \- 1))$, ..., $r a n k(n', t_(e n d \- k))$. $(**)$

  Note that if `refreshNode` observes that an enqueuer has a `Min_timestamp` of `MAX_TIMESTAMP`, it would never try to CAS $n'$'s rank to the rank of that enqueuer (line 46 of @ltqueue-enqueue-refresh-node and line 100 of @ltqueue-dequeue-refresh-node). So, if `refreshNode` actually set the rank of $n'$ to some non-`DUMMY_RANK` value, the corresponding enqueuer must actually has a non-`MAX_TIMESTAMP` `Min-timestamp` _at some point_. Due to $(2)$, this is constant up until $t_1$. Therefore, $m i n \- t s(r a n k(n', t_(e n d \- i)), t))$ is constant for any $t gt.eq t_(e n d \- i)$ and $k gt.eq i gt.eq 1$. $m i n \- t s(r a n k(n', t_(e n d \- 0)), t))$ is constant for any $t gt.eq t_(e n d \- 0)$ if there's a `refreshNode` before $t_0$. If there's no `refreshNode` before $t_0$, it is constantlt `MAX_TIMESTAMP`. So, $m i n \- t s(r a n k(n', t_(e n d \- i)), t))$ is constant for any $t gt.eq t_(e n d \- i)$ and $k gt.eq i gt.eq 0$. $(***)$

  Combining $(*)$, $(**)$, $(***)$, we obtain the stronger version of the theorem.
]

#theorem[If an enqueue $e$ obtains a timestamp $c$, finishes at time $t_0$ and is still *unmatched* at time $t_1$, then for any subrange $T$ of $[t_0, t_1]$ that does not overlap with a dequeue, $m i n \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.] <ltqueue-unmatched-enqueue-theorem>

#proof[
  We will prove a stronger version of this theorem: Suppose an enqueue $e$ obtains a timestamp $c$, finishes at time $t_0$ and is still *unmatched* at time $t_1$. For every $n_i in p a t h(e)$, $n_0$ is the leaf node and $n_i$ is the parent of $n_(i-1)$, $i gt.eq 1$. If $e$ starts and finishes its *node-$n_i$-refresh phase* at $t_(s t a r t\-i)$ and $t_(e n d\-i)$ then for any subrange $T$ of $[t_(e n d\-i), t_1]$ that does not overlap with a dequeue $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node $n_i$ refresh phase*, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  If $t_1 lt t_0$ then the theorem holds.

  Take $r_e$ to be the rank of the enqueuer that performs $e$.

  Suppose $e$ enqueues an item with the timestamp $c$ into the local SPSC at time $t_(e n q u e u e)$. Because it's still unmatched up until $t_1$, $c$ is always in the local SPSC during $t_(e n q u e u e)$ to $t_1$. Therefore, $m i n \- s p s c \- t s(r_e, t) lt.eq c$ for any $t in [t_(e n q u e u e), t_1]$. $(1)$

  Suppose $e$ finishes its *timestamp refresh phase* at $t_(r\-t s)$. Because $t_(r\-t s) gt.eq t_(e n q u e u e)$, due to $(1)$, $m i n \- t s(r_e, t) lt.eq c$ for every $t in [t_(r\-t s),t_1]$. $(2)$

  Consider the leaf node $n_0 in p a t h (e)$. Due to $(2)$, $r a n k(n_0, t)$ is always $r_e$ for any $t in [t_(e n d\-0), t_1]$. Also due to $(2)$, $m i n \- t s(r a n k(n_0, t_r), t_s) lt.eq c$ for any $t_r, t_s in [t_(e n d\-0), t_1]$.

  Consider any non-leaf node $n_i in p a t h(e)$. We can extend any subrange $T$ to the left until we either:
  - Reach a dequeue $d$ such that $n_i in p a t h (d)$ and $d$ has just finished its *node-$n_i$-refresh phase*.
  - Reach $t_(e n d \- i)$.
  Consider one such subrange $T_i$.

  Notice that $T_i$ always starts right after a *node-$n_i$-refresh phase*. Due to @ltqueue-refresh-node-theorem, there's always at least one successful `refreshNode` in this *node-$n_i$-refresh phase*.

  Suppose the stronger version of the theorem already holds for $n_(i-1)$. That is, if $e$ starts and finishes its *node-$n_(i-1)$-refresh phase* at $t_(s t a r t\-(i-1))$ and $t_(e n d\-(i-1))$ then for any subrange $T$ of $[t_(e n d\-(i-1)), t_1]$ that does not overlap with a dequeue $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node $n_(i-1)$ refresh phase*, $m i n \- t s(r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  Extend $T_i$ to the left until we either:
  - Reach a dequeue $d$ such that $n_i in p a t h (d)$ and $d$ has just finished its *node-$n_(i-1)$-refresh phase*.
  - Reach $t_(e n d \- (i-1))$.
  Take the resulting range to be $T_(i-1)$. Obviously, $T_i subset.eq T_(i-1)$.

  $T_(i-1)$ satisifies both criteria:
  - It's a subrange of $[t_(e n d\-(i-1)), t_1]$.
  - It does not overlap with a dequeue $d$ where $n_i in p a t h(d)$ and $d$ hasn't finished its *node-$n_(i-1)$-refresh phase*.
  Therefore, $m i n \- t s(r a n k(n_(i-1), t_r), t_s) lt.eq c$ for any $t_r, t_s in T_(i-1)$.

  Consider the last successful `refreshNode` on $n_i$ ending not after $T_i$, take $t_s'$ and $t_e'$ to be the start and end time of this `refreshNode`'s CAS-sequence. Because right at the start of $T_i$, a *node-$n_i$-refresh phase* just ends, this `refreshNode` must be within this *node-$n_i$-refresh phase*. $(4)$

  This `refreshNode`'s CAS-sequence must be within $T_(i-1)$. This is because right at the start of $T_(i-1)$, a *node-$n_(i-1)$-refresh phase* just ends and $T_(i-1) supset.eq T_i$, $T_(i-1)$ must cover the *node-$n_i$-refresh phase* whose end $T_i$ starts from. Combining with $(4)$, $t_s' in T_(i-1)$ and $t_e' in T_i$. $(5)$

  Due to how `refreshNode` is defined and the fact that $n_(i-1)$ is a child of $n_i$:
  - $t_(r a n k)$ is the time `refreshNode` reads the rank stored in $n_(i-1)$, so that $t_s' lt.eq t_(r a n k) lt.eq t_e'$. Combining with $(5)$, $t_(r a n k) in T_(i-1)$.
  - $t_(t s)$ is the time `refreshNode` reads the timestamp from that rank $t_s' lt.eq t_(t s) lt.eq t_e'$. Combining with $(5)$, $t_(t s) in T_(i-1)$.
  - There exists a time $t'$, $t_s' lt.eq t' lt.eq t_e'$, #linebreak() $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq m i n \- t s (r a n k(n_(i-1), t_(r a n k)), t_(t s))$. $(6)$

  From $(6)$ and the fact that $t_(r a n k) in T_(i-1)$ and $t_(t s) in T_(i-1)$, $m i n \- t s(r a n k(n_i, t_e'), t') lt.eq c$.

  There shall be no `spsc_dequeue` starting within $t_s'$ till the end of $T_i$ because:
  - If there's an `spsc_dequeue` starting within $T_i$, then $T_i$'s assumption is violated.
  - If there's an `spsc_dequeue` starting after $t_s'$ but before $T_i$, its dequeue must finish its *node-$n_i$-refresh phase* after $t_s'$ and before $T_i$. However, then $t_e'$ is no longer the end of the last successful `refreshNode` on $n_i$ not after $T_i$.
  Because there's no `spsc_dequeue` starting in this timespan, $m i n \- t s(r a n k(n_i, t_e'), t_e') lt.eq m i n \- t s(r a n k(n_i, t_e'), t') lt.eq c$.

  If there's no dequeue between $t_e'$ and the end of $T_i$ whose *node-$n_i$-refresh phase* hasn't finished, then by @ltqueue-monotonic-theorem, $m i n \- t s(r a n k(n_i, t_r), t_s)$ is monotonically decreasing for any $t_r$, $t_s$ starting from $t_e'$ till the end of $T_i$. Therefore, $m i n \- t s (r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_i$.

  Suppose there's a dequeue whose *node-$n_i$-refresh phase* is in progress some time between $t_e'$ and the end of $T_i$. By definition, this dequeue must finish it before $T_i$. Because $t_e'$ is the time of the last successful refresh on $n_i$ before $T_i$, $t_e'$ must be within the *node-$n_i$-refresh phase* of this dequeue and there should be no dequeue after that. By the way $t_e'$ is defined, technically, this dequeue has finished its *node-$n_i$-refresh phase* right at $t_e'$. Therefore, similarly, we can apply @ltqueue-monotonic-theorem, $m i n \- t s (r a n k(n_i, t_r), t_s) lt.eq c$ for any $t_r, t_s in T_i$.

  By induction, we have proved the stronger version of the theorem. Therefore, the theorem directly follows.
]

#corollary[Suppose $r o o t$ is the root tree node. If an enqueue $e$ obtains a timestamp $c$, finishes at time $t_0$ and is still *unmatched* at time $t_1$, then for any subrange $T$ of $[t_0, t_1]$ that does not overlap with a dequeue, $m i n \- s p s c \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.] <ltqueue-unmatched-enqueue-corollary>

#proof[
  Call $t_(s t a r t)$ and $t_(e n d)$ to be the start and end time of $T$.

  Applying @ltqueue-unmatched-enqueue-theorem, we have that $m i n \- t s(r a n k(r o o t, t_r), t_s) lt.eq c$ for any $t_r, t_s in T$.

  Fix $t_r$ so that $r a n k(r o o t, t_r) = r$. We have that $m i n \- t s(r, t) lt.eq c$ for any $t in T$.

  $m i n \- t s(r, t)$ can only change due to a successful `refreshTimestamp` on the enqueuer node with rank $r$. Consider the last successful `refreshTimestamp` on the enqueuer node with rank $r$ not after $T$. Suppose that `refreshTimestamp` reads out the minimum timestamp of the local SPSC at $t' lt.eq t_(s t a r t)$.

  Therefore, $m i n \- t s(r, t_(s t a r t)) = m i n \- s p s c \- t s(r, t') lt.eq c$.

  We will prove that after $t'$ until $t_(e n d)$, there's no `spsc_dequeue` on $r$ running.

  Suppose the contrary, then this `spsc_dequeue` must be part of a dequeue. By definition, this dequeue must start and end before $t_(s t a r t)$, else it violates the assumption of $T$. If this `spsc_dequeue` starts after $t'$, then its `refreshTimestamp` must finish after $t'$ and before $t_(s t a r t)$. But this violates the assumption that the last `refreshTimestamp` not after $t_(s t a r t)$ reads out the minimum timestamp at $t'$.

  Therefore, there's no `spsc_dequeue` on $r$ running during $[t', t_(e n d)]$. Therefore, $m i n \- s p s c \- t s(r, t)$ remains constant during $[t', t_(e n d)]$ because it's not `MAX_TIMESTAMP`.

  In conclusion, $m i n \- s p s c \- t s(r, t) lt.eq c$ for $t in[t', t_(e n d)]$.

  We have proved the theorem.
]

#theorem[Given a rank $r$. If within $[t_0, t_1]$, there's no uncompleted enqueues on rank $r$ and all matching dequeues for any completed enqueues on rank $r$ has finished, then $r a n k(n, t) eq.not r$ for every node $n$ and $t in [t_0, t_1]$.] <ltqueue-matched-enqueue-theorem>

#proof[
  If $n$ doesn't lie on the path from root to the leaf node that's attached to the enqueuer node with rank $r$, the theorem obviously holds.

  Due to @ltqueue-one-dequeue-one-enqueue-corollary, there can only be one enqueue and one dequeue at a time at an enqueuer node with rank $r$. Therefore, there is a sequential ordering among the enqueues and a sequential ordering within the dequeues. Therefore, it's sensible to talk about the last enqueue before $t_0$ and the last matched dequeue $d$ before $t_0$.

  Since all of these dequeues and enqueues work on the same local SPSC and the SPSC is linearizable, $d$ must match the last enqueue. After this dequeue $d$, the local SPSC is empty.

  When $d$ finishes its *timestamp-refresh phase* at $t_(t s) lt.eq t_0$, due to @ltqueue-refresh-timestamp-theorem, there's at least one successful `refreshTimestamp` call in this phase. Because the last enqueue has been matched, $m i n \- t s(r, t) =$ `MAX_TIMESTAMP` for any $t in [t_(t s), t_1]$.

  Similarly, for a leaf node $n_0$, suppose $d$ finishes its *node-$n_0$-refresh phase* at $t_(r\-0) gt.eq t_(t s)$, then $r a n k(n_0, t) =$ `DUMMY_RANK` for any $t in [t_(r\-0), t_1]$. $(1)$

  For any non-leaf node $n_i in p a t h(d)$, when $d$ finishes its *node-$n_i$-refresh phase* at $t_(r\-i)$, there's at least one successful `refreshNode` call during this phase. Suppose this `refreshNode` call starts and ends at $t_(s t a r t \- i)$ and $t_(e n d\-i)$. Suppose $r a n k(n_(i-1), t) eq.not r$ for $t in [t_(r\-(i-1)), t_1]$. By the way `refreshNode` is defined after this `refreshNode` call, $n_i$ will store some rank other than $r$. Because of $(1)$, after this up until $t_1$, $r$ never has a chance to be visible to a `refreshNode` on node $n_i$ during $[n_(i-1), t]$. In other words, $r a n k(n_i, t) eq.not r$ for $t in [t_(r\-i), t_1]$.

  By induction, we obtain the theorem.
]

#theorem[In dLTQueue, if an enqueue $e$ precedes another dequeue $d$, then either:
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

  Because $e$ precedes $d$ and because an MPSC queue does not allow multiple dequeues, from the start of $d$ at $t_0$ until after line 4 of dequeue (@ltqueue-dequeue) at $t_1$, $e$ has finished and there's no dequeue running that has _actually performed `spsc_dequeue`_. Also by $t_0$ and $t_1$, $e$ is still unmatched due to $(1)$.

  Applying @ltqueue-unmatched-enqueue-corollary, $m i n \- s p s c \- t s(r a n k(r o o t, t_x), t_y) lt.eq c$ for $t_x, t_y in [t_0, t_1]$. Therefore, $d$ reads out a rank $r$ such that $m i n \- s p s c \- t s(r, t) lt.eq c$ for $t in [t_0, t_1]$. Consequently, $d$ dequeues out a value with a timestamp not greater than $c$. Because $d$ matches $e'$, $c' lt.eq c$. However, $e' eq.not e$ so $c' lt c$.

  This means that $e$ cannot precede $e'$, because if so, $c lt c'$.

  Therefore, $e'$ precedes $e$ or overlaps with $e$.
]

#theorem[
  In dLTQueue, if $d$ matches $e$, then either $e$ precedes or overlaps with $d$.
] <ltqueue-matching-dequeue-enqueue-theorem>

#proof[
  If $d$ precedes $e$, none of the local SPSCs can contain an item with the timestamp of $e$. Therefore, $d$ cannot return an item with a timestamp of $e$. Thus $d$ cannot match $e$.

  Therefore, $e$ either precedes or overlaps with $d$.
]

#theorem[In dLTQueue, If a dequeue $d$ precedes another enqueue $e$, then either:
  - $d$ isn't matched.
  - $d$ matches $e'$ such that $e'$ precedes or overlaps with $e$ and $e' eq.not e$.
] <ltqueue-dequeue-enqueue-theorem>

#proof[
  If $d$ isn't matched, the theorem holds.

  Suppose $d$ matches $e'$. Applying @ltqueue-matching-dequeue-enqueue-theorem, $e'$ must precede or overlap with $d$. In other words, $d$ cannot precede $e'$.

  If $e$ precedes or is $e'$, then $d$ must precede $e'$, which is contradictory.

  Therefore, $e'$ must precede $e$ or overlap with $e$.
]

#theorem[In dLTQueue, if an enqueue $e_0$ precedes another enqueue $e_1$, then either:
  - Both $e_0$ and $e_1$ aren't matched.
  - $e_0$ is matched but $e_1$ is not matched.
  - $e_0$ matches $d_0$ and $e_1$ matches $d_1$ such that $d_0$ precedes $d_1$.
] <ltqueue-enqueue-enqueue-theorem>

#proof[
  If both $e_0$ and $e_1$ aren't matched, the theorem holds.

  Suppose $e_1$ matches $d_1$. By @ltqueue-matching-dequeue-enqueue-theorem, either $e_1$ precedes or overlaps with $d_1$.

  If $e_0$ precedes $d_1$, applying @ltqueue-enqueue-dequeue-theorem for $d_1$ and $e_0$:
  - $d_1$ isn't matched, contradictory.
  - $d_1$ matches $e_0$, contradictory.
  - $e_0$ matches $d_0$ and $d_0$ precedes $d_1$, the theorem holds.
  - $d_1$ matches $e_1$ and $e_1$ precedes $e_0$, contradictory.
  - $d_1$ matches $e_1$ and $e_1$ overlaps with $e_0$, contradictory.

  If $d_1$ precedes $e_0$, applying @ltqueue-dequeue-enqueue-theorem for $d_1$ and $e_0$:
  - $d_1$ isn't matched, contradictory.
  - $d_1$ matches $e_1$ and $e_1$ precedes or overlaps with $e_0$, contradictory.

  Consider that $d_1$ overlaps with $e_0$, then $d_1$ must also overlap with $e_1$. Call $r_1$ the rank of the enqueuer that performs $e_1$. Call $t$ to be the time $d_1$ atomically reads the root's rank on line 4 of dequeue (@ltqueue-dequeue). Because $d_1$ matches $e_1$, $d_1$ must read out $r_1$ at $t_1$.

  If $e_1$ is the first enqueue of rank $r_1$, then $t$ must be after $e_1$ has started, because otherwise, due to @ltqueue-matched-enqueue-theorem, $r_1$ would not be in $r o o t$ before $e_1$.

  If $e_1$ is not the first enqueue of rank $r_1$, then $t$ must also be after $e_1$ has started. Suppose the contrary, $t$ is before $e_1$ has started:
  - If there's no uncompleted enqueue of rank $r_1$ at $t$ and they are all matched by the time $t$, due to @ltqueue-matched-enqueue-theorem, $r_1$ would not be in $r o o t$ at $t$. Therefore, $d_1$ cannot read out $r_1$, which is contradictory.
  - If there's some unmatched enqueue of rank $r_1$ at $t$, $d_1$ will match one of these enqueues instead because:
    - There's only one dequeue at a time, so unmatched enqueues at $t$ remain unmatched until $d_1$ performs an `spsc_dequeue`.
    - Due to @ltqueue-one-dequeue-one-enqueue-corollary, all the enqueues of rank $r_1$ must finish before another starts. Therefore, there's some unmatched enqueue of rank $r_1$ finishing before $e_1$.
    - The local SPSC of the enqueuer node of rank $r_1$ is serializable, so $d_1$will favor one of these enqueues over $e_1$.

  Therefore, $t$ must happen after $e_1$ has started. Right at $t$, no dequeue is actually modifying the dLTQueue state and $e_0$ has finished. If $e_0$ has been matched at $t$ then the theorem holds. If $e_0$ hasn't been matched at $t$, applying @ltqueue-unmatched-enqueue-theorem, $d_1$ will favor $e_0$ over $e_1$, which is a contradiction.

  We have proved the theorem.
]

#theorem[In dLTQueue, if a dequeue $d_0$ precedes another dequeue $d_1$, then either:
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

#theorem(
  name: "Linearizability of dLTQueue",
)[The dLTQueue algorithm is linearizable.]

#proof[
  Suppose some history $H$ produced from the modified dLTQueue algorithm.

  If $H$ contains some pending method calls, we can just wait for them to complete (because the algorithm is wait-free, which we will prove later). Therefore, now we consider all $H$ to contain only completed method calls. So, we know that if a dequeue or an enqueue in $H$ is matched or not.

  If there are some unmatched enqueues, we can append dequeues sequentially to the end of $H$ until there's no unmatched enqueues. Consider one such $H'$.

  We already have a strict partial order $->$#sub($H'$) on $H'$.

  Because the queue is MPSC, there's already a total order among the dequeues.

  We will extend $->$#sub($H'$) to a strict total order $=>$#sub($H'$) on $H'$ as follows:
  - If $X ->$#sub($H'$)$Y$ then $X =>$#sub($H'$)$Y$. $(1)$
  - If a dequeue $d$ matches $e$ then $e =>$#sub($H'$)$d$. $(2)$
  - If a dequeue $d_0$ matches $e_0$ and another dequeue matches $e_1$ such that $d_0 =>$#sub($H'$)$d_1$ then $e_0 =>$#sub($H'$)$e_1$. $(3)$
  - If a dequeue $d$ overlaps with an enqueue $e$ but does not match $e$, $d =>$#sub($H'$)$e$. $(4)$

  We will prove that $=>$#sub($H'$) is a strict total order on $H'$. That is, for every pair of different method calls $X$ and $Y$, either exactly one of these is true $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ and for any $X$, $X arrow.double.not$#sub($H'$)$X$.

  It's obvious that $X arrow.double.not$#sub($H'$)$X$.

  If $X$ and $Y$ are dequeues, because there's a total order among the dequeues, either exactly one of these is true: $X ->$#sub($H'$)$Y$ or $Y ->$#sub($H'$)$X$. Then due to $(1)$, either $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$. Notice that we cannot obtain $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ from $(2)$, $(3)$, or $(4)$.
  #linebreak()
  Therefore, exactly one of $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ is true. $(*)$

  If $X$ is a dequeue and $Y$ is a enqueue, in this case $(3)$ cannot help us obtain either $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$, so we can disregard it.
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

  If $X$ is an enqueue and $Y$ is an enqueue, in this case $(2)$ and $(4)$ are irrelevant:
  - If $X ->$#sub($H'$)$Y$, then due to $(1)$, $X =>$#sub($H'$)$Y$. By definition, $X$ precedes $Y$. Applying @ltqueue-enqueue-enqueue-theorem,
    - Both $X$ and $Y$ aren't matched, then $(3)$ cannot apply. Therefore, in this case, $Y arrow.double.not$#sub($H'$)$X$.
    - $X$ is matched but $Y$ is not matched, then $(3)$ cannot apply. Therefore, in this case, $Y arrow.double.not$#sub($H'$)$X$.
    - $X$ matches $d_x$ and $Y$ matches $d_y$ such that $d_x$ precedes $d_y$, then $(3)$ applies and we obtain $X arrow.double$#sub($H'$)$Y$.
    Therefore, in this case, $X arrow.double$#sub($H'$)$Y$ but $Y arrow.double.not$#sub($H'$)$X$.
  - If $Y ->$#sub($H'$)$X$, this case is symmetric to the first case. We obtain $Y arrow.double$#sub($H'$)$X$ but $X arrow.double.not$#sub($H'$)$Y$.
  - If $X$ overlaps with $Y$, because in $H'$, all enqueues are matched, then, $X$ matches $d_x$ and $d_y$. Because $d_x$ either precedes or succeeds $d_y$, Applying $(3)$, we obtain either $X arrow.double$#sub($H'$)$Y$ or $Y arrow.double$#sub($H'$)$X$ and there's no way to obtain the other.
  Therefore, exactly one of $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ is true. $(***)$

  From $(*)$, $(**)$, $(***)$, we have proved that $=>$#sub($H'$) is a strict total ordering that is consistent with $->$#sub($H'$). In other words, we can order method calls in $H'$ in a sequential manner. We will prove that this sequential order is consistent with FIFO semantics:
  - An enqueue can only be matched by one dequeue: This follows from @ltqueue-unique-match-enqueue.
  - A dequeue can only be matched by one enqueue: This follows from @ltqueue-unique-match-dequeue.
  - The order of item dequeues is the same as the order of item enqueues: Suppose there are two enqueues $e_1$, $e_2$ such that $e_1 arrow.double$#sub($H'$)$e_2$ and suppose they match $d_1$ and $d_2$. Then we have obtained $e_1 arrow.double$#sub($H'$)$e_2$ either because:
    - $(3)$ applies, in this case $d_1 arrow.double$#sub($H'$)$d_2$ is a condition for it to apply.
    - $(1)$ applies, then $e_1$ precedes $e_2$, by @ltqueue-enqueue-enqueue-theorem, $d_1$ must precede $d_2$, thus $d_1 arrow.double$#sub($H'$)$d_2$.
    Therefore, if $e_1 arrow.double$#sub($H'$)$ e_2$ then $d_1 arrow.double$#sub($H'$)$d_2$.
  - An enqueue can only be matched by a later dequeue: Suppose there is an enqueue $e$ matched by $d$. By $(2)$, obviously $e =>$#sub($H'$)$d$.
    - If the queue is empty, dequeues return `false`. Suppose a dequeue $d$ such that any $e arrow.double$#sub($H'$)$d$ is all matched by some $d'$ and $d' arrow.double$#sub($H'$)$d$, we will prove that $d$ is unmatched. By @ltqueue-matching-dequeue-enqueue-theorem, $d$ can only match an enqueue $e_0$ that precedes or overlaps with $d$.
      - If $e_0$ precedes $d$, by our assumption, it's already matched by another dequeue.
      - If $e_0$ overlaps with $d$, by our assumption, $d arrow.double$#sub($H'$)$e_0$ because if $e_0 arrow.double$#sub($H'$)$d$, $e_0$ is already matched by another $d'$. Then, we can only obtain this because $(4)$ applies, but then $d$ does not match $e_0$.
    Therefore, $d$ is unmatched.
  - A dequeue returns `false` when the queue is empty: To put more precisely, for a dequeue $d$, if every successful enqueue $e'$ such that $e' =>$#sub($H'$)$d$ has been matched by $d'$ such that $d' =>$#sub($H'$)$d$, then $d$ would be unmatched and return `false`. Suppose the contrary, $d$ matches $e$. By definition, $e =>$#sub($H'$)$d$. This is a contradiction by our assumption.
  - A dequeue returns `true` and matches an enqueue when the queue is not empty: To put more precisely, for a dequeue $d$, if there exists a successful enqueue $e'$ such that $e' =>$#sub($H'$)$d$ and has not been matched by a dequeue $d'$ such that $d' =>$#sub($H'$)$e'$, then $d$ would be match some $e$ and return `true`. This follows from @ltqueue-unmatched-enqueue-theorem.
  - An enqueue that returns `true` will be matched if there are enough dequeues after that: Based on how @ltqueue-enqueue is defined, when an enqueue returns `true`, it has successfully execute `spsc_enqueue`. By @ltqueue-unmatched-enqueue-theorem, at some point, it would eventually be matched.
  - An enqueue that returns `false` will never be matched: Based on how @ltqueue-enqueue is defined, when an enqueue returns `false`, the state of dLTQueue is not changed, except for the distributed counter. Therefore, it could never be matched.

  In conclusion, $=>$#sub($H'$) is a way we can order method calls in $H'$ sequentially that conforms to FIFO semantics. Therefore, we can also order method calls in $H$ sequentially that conforms to FIFO semantics as we only append dequeues sequentially to the end of $H$ to obtain $H'$.

  We have proved the theorem.
]

=== Progress guarantee

Notice that every loop in dLTQueue is bounded, and no method have to wait for another. Therefore, dLTQueue is wait-free.

=== Performance model

== Theoretical proofs of Slotqueue

In this section, we provide proofs covering all of our interested theoretical aspects in Slotqueue.

=== Proof-specific notations

As a refresher, @remind-slotqueue-structure shows the structure of Slotqueue.

#figure(
  image("/static/images/slotqueue.png"),
  caption: [Basic structure of Slotqueue.],
) <remind-slotqueue-structure>

Each enqueuer hosts an SPSC that can only accessed by itself and the dequeuer. The dequeuer hosts an array of slots, each slot corresponds to an enqueuer, containing its SPSC's minimum timestamp.

We apply some domain knowledge of Slotqueue algorithm to the definitions introduced in @ABA-safety.

#definition[A *CAS-sequence* on a slot `s` of an enqueue that affects `s` is the sequence of instructions from line 15 to line 20 of its `refreshEnqueue` (@slotqueue-refresh-enqueue).]

#definition[A *slot-modification instruction* on a slot `s` of an enqueue that affects `s` is line 20 of `refreshEnqueue` (@slotqueue-refresh-enqueue).]

#definition[A *CAS-sequence* on a slot `s` of a dequeue that affects `s` is the sequence of instructions from line 50 to line 54 of its `refreshDequeue` (@slotqueue-refresh-dequeue).]

#definition[A *slot-modification instruction* on a slot `s` of a dequeue that affects `s` is line 54 of `refreshDequeue` (@slotqueue-refresh-dequeue).]

#definition[A *CAS-sequence* of a dequeue/enqueue is said to *observe a slot value of $s_0$* if it loads $s_0$ at line 15 of `refreshEnqueue` or line 50 of `refreshDequeue`.]

The followings are some other definitions that will be used throughout our proof.

#definition[For an enqueue or dequeue $o p$, $r a n k(o p)$ is the rank of the enqueuer whose local SPSC is affected by $o p$.]

#definition[For an enqueuer whose rank is $r$, the value stored in its corresponding slot at time $t$ is denoted as $s l o t(r, t)$.]

#definition[For an enqueuer with rank $r$, the minimum timestamp among the elements between `First` and `Last` in its local SPSC at time $t$ is denoted as $m i n \- s p s c \- t s(r, t)$.]

#definition[For an enqueue, *slot-refresh phase* refer to its execution of line 5-6 of @slotqueue-enqueue.]

#definition[For a dequeue, *slot-refresh phase* refer to its execution of line 28-29 of @slotqueue-dequeue.]

#definition[For a dequeue, *slot-scan phase* refer to its execution of line 31-47 of @slotqueue-read-minimum-rank.]

=== Correctness

==== ABA problem

Noticeably, we use no scheme to avoid ABA problem in Slotqueue. In actuality, ABA problem does not adversely affect our algorithm's correctness, except in the extreme case that the 64-bit distributed counter overflows, which is unlikely.

We will prove that Slotqueue is ABA-safe, as introduced in @ABA-safety.

Notice that we only use `CAS`es on:
- Line 20 of `refreshEnqueue` (@slotqueue-refresh-enqueue), which is part of an enqueue.
- Line 54 of `refreshDequeue` (@slotqueue-refresh-dequeue), which is part of a dequeue.

Both `CAS`es target some slot in the `Slots` array.

#theorem(name: "Concurrent accesses on an SPSC and a slot")[
  Only one dequeuer and one enqueuer can concurrently modify an SPSC and a slot in the `Slots` array.
] <slotqueue-one-enqueuer-one-dequeuer-theorem>

#proof[
  This is trivial to prove based on the algorithm's definition.
]

#theorem(name: "Monotonicity of SPSC timestamps")[
  Each SPSC in Slotqueue contains elements with increasing timestamps.
] <slotqueue-spsc-timestamp-monotonicity-theorem>

#proof[
  Each enqueue would `FAA` the distributed counter (line 3 in @slotqueue-enqueue) and enqueue into the local SPSC an item with the timestamp obtained from the counter. Applying @slotqueue-one-enqueuer-one-dequeuer-theorem, we know that items are enqueued one at a time into the SPSC. Therefore, later items are enqueued by later enqueues, which obtain increasing values by `FAA`-ing the shared counter. The theorem holds.
]

#theorem[A `refreshEnqueue` (@slotqueue-refresh-enqueue) can only change a slot to a value other than `MAX_TIMESTAMP`.] <slotqueue-refresh-enqueue-CAS-to-non-MAX-theorem>

#proof[
  For `refreshEnqueue` to change the slot's value, the condition on line 18 must be `false`. Then, `new_timestamp` must equal to `ts`, which is not `MAX_TIMESTAMP`. It's obvious that the `CAS` on line 20 changes the slot to a value other than `MAX_TIMESTAMP`.
]

#theorem(
  name: [ABA safety of dequeue],
)[Assume that the 64-bit distributed counter never overflows, dequeue (@slotqueue-dequeue) is ABA-safe.] <slotqueue-aba-safe-dequeue-theorem>

#proof[
  Consider a *successful CAS-sequence* on slot `s` by a dequeue $d$. Denote $t_d$ as the value this CAS-sequence observes.

  If there's no *successful slot-modification instruction* on slot `s` by an enqueue $e$ within $d$'s *successful CAS-sequence*, then this dequeue is ABA-safe.

  Suppose the enqueue $e$ executes the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*. Denote $t_e$ to be the value that $e$ sets `s` $(*)$.

  If $t_e != t_d$, this CAS-sequence of $d$ cannot be successful, which is a contradiction. Therefore, $t_e = t_d$.

  Note that $e$ can only set `s` to the timestamp of the item it enqueues. That means, $e$ must have enqueued a value with timestamp $t_d$. However, by definition $(*)$, $t_d$ is read before $e$ executes the CAS, so $d$ cannot observe $t_d$ because $e$ has CAS-ed slot `s`. This means another process (dequeuer/enqueuer) has seen the value $e$ enqueued and CAS `s` for $e$ before $t_d$. By @slotqueue-one-enqueuer-one-dequeuer-theorem, this "another process" must be another dequeuer $d'$ that precedes $d$ because it overlaps with $e$.

  Because $d'$ and $d$ cannot overlap, while $e$ overlaps with both $d'$ and $d$, $e$ must be the _first_ enqueue on `s` that overlaps with $d$. Combining with @slotqueue-one-enqueuer-one-dequeuer-theorem and the fact that $e$ executes the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*, $e$ must be the only enqueue that executes a *successful slot-modification instruction* on `s` within $d$'s *successful CAS-sequence*.

  During the start of $d$'s successful CAS-sequence till the end of $e$, `spsc_readFront` on the local SPSC must return the same element, because:
  - There's no other dequeue running during this time.
  - There's no enqueue other than $e$ running.
  - The `spsc_enqueue` of $e$ must have completed before the start of $d$'s successful CAS sequence, because a previous dequeuer $d'$ can see its effect.
  Therefore, if we were to move the starting time of $d$'s successful CAS-sequence right after $e$ has ended, we still retain the output of the program because:
  - The CAS sequence only reads two shared values: the `rank`th entry of `Slots` and `spsc_readFront()`, but we have proven that these two values remain the same if we were to move the starting time of $d$'s successful CAS-sequence this way.
  - The CAS sequence does not modify any values except for the last CAS instruction, and the ending time of the CAS sequence is still the same.
  - The CAS sequence modifies the `rank`th entry of `Slots` at the CAS but the target value is the same because inputs and shared values are the same in both cases.

  We have proved that if we move $d$'s successful CAS-sequence to start after the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*, we still retain the program's output.

  If we apply the reordering for every dequeue, the theorem directly follows.
]

#theorem(
  name: [ABA safety of enqueue],
)[Assume that the 64-bit distributed counter never overflows, enqueue (@slotqueue-enqueue) is ABA-safe.] <slotqueue-aba-safe-enqueue-theorem>

#proof[
  Consider a *successful CAS-sequence* on slot `s` by an enqueue $e$. Denote $t_e$ as the value this CAS-sequence observes.

  If there's no *successful slot-modification instruction* on slot `s` by a dequeue $d$ within $e$'s *successful CAS-sequence*, then this enqueue is ABA-safe.

  Suppose the dequeue $d$ executes the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*. Denote $t_d$ to be the value that $d$ sets `s`. If $t_d != t_e$, this CAS-sequence of $e$ cannot be successful, which is a contradiction $(*)$.

  Therefore, $t_d = t_e$.

  If $t_d = t_e = $ `MAX_TIMESTAMP`, this means $e$ observes a value of `MAX_TIMESTAMP` before $d$ even sets `s` to `MAX_TIMESTAMP` due to $(*)$. If this `MAX_TIMESTAMP` value is the initialized value of `s`, it's a contradiction, as `s` must be non-`MAX_TIMESTAMP` at some point for a dequeue such as $d$ to enter its CAS sequence. If this `MAX_TIMESTAMP` value is set by an enqueue, it's also a contradiction, as `refreshEnqueue` cannot set a slot to `MAX_TIMESTAMP`. Therefore, this `MAX_TIMESTAMP` value is set by a dequeue $d'$. If $d' != d$ then it's a contradiction, because between $d'$ and $d$, `s` must be set to be a non-`MAX_TIMESTAMP` value before $d$ can be run, thus, $e$ cannot have observed a value set by $d'$. Therefore, $d' = d$. But, this means $e$ observes a value set by $d$, which violates our assumption $(*)$.

  Therefore $t_d = t_e = t' != $ `MAX_TIMESTAMP`. $e$ cannot observe the value $t'$ set by $d$ due to our assumption $(*)$. Suppose $e$ observes the value $t'$ from `s` set by another enqueue/dequeue call other than $d$.

  If this "another call" is a dequeue $d'$ other than $d$, $d'$ precedes $d$. By @slotqueue-spsc-timestamp-monotonicity-theorem, after each dequeue, the front element's timestamp will be increasing, therefore, $d'$ must have set `s` to a timestamp smaller than $t_d$. However, $e$ observes $t_e = t_d$. This is a contradiction.

  Therefore, this "another call" is an enqueue $e'$ other than $e$ and $e'$ precedes $e$. We know that an enqueue only sets `s` to the timestamp it obtains.

  Suppose $e'$ does not overlap with $d$, then $e$ precedes $d$. $e'$ can only set `s` to $t'$ if $e'$ sees that the local SPSC has the front element as the element it enqueues. Due to @slotqueue-one-enqueuer-one-dequeuer-theorem, this means $e'$ must observe a local SPSC with only the element it enqueues. Then, when $d$ executes `readFront`, the item $e'$ enqueues must have been dequeued out already, thus, $d$ cannot set `s` to $t'$. This is a contradiction.

  Therefore, $e'$ overlaps with $d$.

  Because $e'$ and $e$ cannot overlap, while $d$ overlaps with both $e'$ and $e$, $d$ must be the _first_ dequeue on `s` that overlaps with $e$. Combining with @slotqueue-one-enqueuer-one-dequeuer-theorem and the fact that $d$ executes the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*, $d$ must be the only dequeue that executes a *successful slot-modification instruction* within $e$'s *successful CAS-sequence*.

  During the start of $e$'s successful CAS-sequence till the end of $d$, `spsc_readFront` on the local SPSC must return the same element, because:
  - There's no other enqueue running during this time.
  - There's no dequeue other than $d$ running.
  - The `spsc_dequeue` of $d$ must have completed before the start of $e$'s successful CAS sequence, because a previous enqueuer $e'$ can see its effect.
  Therefore, if we were to move the starting time of $e$'s successful CAS-sequence right after $d$ has ended, we still retain the output of the program because:
  - The CAS sequence only reads two shared values: the `rank`th entry of `Slots` and `spsc_readFront()`, but we have proven that these two values remain the same if we were to move the starting time of $e$'s successful CAS-sequence this way.
  - The CAS sequence does not modify any values except for the last CAS/store instruction, and the ending time of the CAS sequence is still the same.
  - The CAS sequence modifies the `rank`th entry of `Slots` at the CAS but the target value is the same because inputs and shared values are the same in both cases.

  We have proved that if we move $e$'s successful CAS-sequence to start after the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*, we still retain the program's output.

  If we apply the reordering for every enqueue, the theorem directly follows.
]

#theorem(
  name: "ABA safety",
)[Assume that the 64-bit distributed counter never overflows, Slot-queue is ABA-safe.] <aba-safe-slotqueue-theorem>

#proof[
  This follows from @slotqueue-aba-safe-enqueue-theorem and @slotqueue-aba-safe-dequeue-theorem.
]

==== Memory reclamation

==== Linearizability

#theorem[In Slotqueue, an enqueue can only match at most one dequeue.] <slotqueue-unique-match-enqueue>

#proof[A dequeue indirectly performs a value dequeue through `spsc_dequeue`. Because `spsc_dequeue` can only match one `spsc_enqueue` by another enqueue, the theorem holds.]

#theorem[In Slotqueue, a dequeue can only match at most one enqueue.] <slotqueue-unique-match-dequeue>

#proof[This is trivial as a dequeue can only read out at most one value, so it can only match at most one enqueue.]

#theorem[If an enqueue $e$ begins its *slot-refresh phase* at time $t_0$ and finishes at time $t_1$, there's always at least one successful `refreshEnqueue` that either doesn't execute its *CAS sequence* or starts and ends its *CAS-sequence* between $t_0$ and $t_1$ or a successful `refreshDequeue` on $r a n k(e)$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$.] <slotqueue-refresh-enqueue-theorem>

#proof[
  If one of the two `refreshEnqueue`s succeeds, then the theorem obviously holds.

  Consider the case where both fail.

  The first `refreshEnqueue` fails because it tries to execute its *CAS-sequence* but there's another `refreshDequeue` executing its *slot-modification instruction* successfully after $t_0$ but before the end of the first `refreshEnqueue`'s *CAS-sequence*.

  The second `refreshEnqueue` fails because it tries to execute its *CAS-sequence* but there's another `refreshDequeue` executing its *slot-modification instruction* successfully after $t_0$ but before the end of the second `refreshEnqueue`'s *CAS-sequence*. This another `refreshDequeue` must start its *CAS-sequence* after the end of the first successful `refreshDequeue`, due to @slotqueue-one-enqueuer-one-dequeuer-theorem. In other words, this another `refreshDequeue` starts and successfully ends its *CAS-sequence* between $t_0$ and $t_1$.

  We have proved the theorem.
]

#theorem[If a dequeue $d$ begins its *slot-refresh phase* at time $t_0$ and finishes at time $t_1$, there's always at least one successful `refreshEnqueue` or `refreshDequeue` on $r a n k(d)$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$.] <slotqueue-refresh-dequeue-theorem>

#proof[This is similar to the above theorem.]

#theorem[
  Given a rank $r$, if an enqueue $e$ on $r$ that obtains the timestamp $c$ completes at $t_0$ and is still unmatched by $t_1$, then $s l o t (r, t) lt.eq c$ for any $t in [t_0, t_1]$.
] <slotqueue-unmatched-enqueue-theorem>

#proof[
  Take $t'$ to be the time $e$'s `spsc_enqueue` takes effect.

  At some point after $t'$, $e$ must enter its *slot-refresh phase*. By @slotqueue-refresh-enqueue-theorem, there must be a successful refresh call after $t'$. If this refresh call executes a *CAS-sequence* at $t'' gt.eq t'$, $t'' in [t', t_0]$, this *CAS-sequence* must observe the effect of `spsc_enqueue`. Therefore, $s l o t (r, t'') lt.eq c$. If this refresh call doesn't execute a *CAS-sequence*, it must be a `refreshEnqueue` seeing that the front timestamp is different from the enqueued timestamp at $t''$, $t'' in [t', t_0]$. Because $e$ is unmatched up until $t_1$ and due to @slotqueue-spsc-timestamp-monotonicity-theorem, $s l o t (r, t'') lt.eq c$.

  By the same reasoning as in @aba-safe-slotqueue-theorem, any successful slot-modification instructions happening after $t''$ must observe the effect of $e$'s `spsc_enqueue`. However, because $e$ is never matched between $t''$ and $t_1$, the timestamp $c$ is in the local SPSC the whole timespan $[t'', t_1]$. Therefore, any slot-modification instructions during $[t'', t_1]$ must set the slot's value to some value not greater than $c$.
]

#theorem[In Slotqueue, if an enqueue $e$ precedes another dequeue $d$, then either:
  - $d$ isn't matched.
  - $d$ matches $e$.
  - $e$ matches $d'$ and $d'$ precedes $d$.
  - $d$ matches $e'$ and $e'$ precedes $e$.
  - $d$ matches $e'$ and $e'$ overlaps with $e$.
] <slotqueue-enqueue-dequeue-theorem>

#proof[
  If $d$ doesn't match anything, the theorem holds. If $d$ matches $e$, the theorem also holds. Suppose $d$ matches $e'$, $e' eq.not e$.

  If $e$ matches $d'$ and $d'$ precedes $d$, the theorem also holds. Suppose $e$ matches $d'$ such that $d$ precedes $d'$ or is unmatched. $(1)$

  Suppose $e$ obtains a timestamp of $c$ and $e'$ obtains a timestamp of $c'$.

  Due to $(1)$, at the time $d$ starts, $e$ has finished but it is still unmatched. By the way @slotqueue-read-minimum-rank is defined and by @slotqueue-unmatched-enqueue-theorem, $d$ would find a slot that stores a timestamp that is not greater than the one $e$ enqueues. In other word, $c' lt.eq c$. But $c' != c$, then $c' < c$. Therefore, $e$ cannot precede $e'$, otherwise, $c < c'$.

  So, either $e'$ precedes or overlaps with $e$. The theorem holds.
]

#theorem[
  In Slotqueue, if $d$ matches $e$, then either $e$ precedes or overlaps with $d$.
] <slotqueue-matching-dequeue-enqueue-theorem>

#proof[
  If $d$ precedes $e$, none of the local SPSCs can contain an item with the timestamp of $e$. Therefore, $d$ cannot return an item with a timestamp of $e$. Thus $d$ cannot match $e$.

  Therefore, $e$ either precedes or overlaps with $d$.
]

#theorem[In Slotqueue, if a dequeue $d$ precedes another enqueue $e$, then either:
  - $d$ isn't matched.
  - $d$ matches $e'$ such that $e'$ precedes or overlaps with $e$ and $e' eq.not e$.
] <slotqueue-dequeue-enqueue-theorem>

#proof[
  If $d$ isn't matched, the theorem holds.

  Suppose $d$ matches $e'$. By @slotqueue-matching-dequeue-enqueue-theorem, either $e'$ precedes or overlaps with $d$. Therefore, $e' != e$. Furthermore, $e$ cannot precede $e'$, because then $d$ would precede $e'$.

  We have proved the theorem.
]

#theorem[If an enqueue $e_0$ precedes another enqueue $e_1$, then either:
  - Both $e_0$ and $e_1$ aren't matched.
  - $e_0$ is matched but $e_1$ is not matched.
  - $e_0$ matches $d_0$ and $e_1$ matches $d_1$ such that $d_0$ precedes $d_1$.
] <slotqueue-enqueue-enqueue-theorem>

#proof[
  If $e_1$ is not matched, the theorem holds.

  Suppose $e_1$ matches $d_1$. By @slotqueue-matching-dequeue-enqueue-theorem, either $e_1$ precedes or overlaps with $d_1$.

  Suppose the contrary, $e_0$ is unmatched or $e_0$ matches $d_0$ such that $d_1$ precedes $d_0$, then when $d_1$ starts, $e_0$ is still unmatched.

  If $e_0$ and $e_1$ targets the same rank, it's obvious that $d_1$ must prioritize $e_0$ over $e_1$. Thus $d_1$ cannot match $e_1$.

  If $e_0$ targets a later rank than $e_1$, $d_1$ cannot find $e_1$ in the first scan, because the scan is left-to-right, and if it finds $e_1$ it would later find $e_0$ that has a lower timestamp. Suppose $d_1$ finds $e_1$ in the second scan, that means $d_1$ finds $e' != e_1$ and $e'$'s timestamp is larger than $e_1$'s, which is larger than $e_0$'s. Due to the scan being left-to-right, $e'$ must target a later rank than $e_1$. If $e'$ also targets a later rank than $e_0$, then in the second scan, $d_1$ would have prioritized $e_0$ that has a lower timestamp. Suppose $e'$ targets an earlier rank than $e_0$ but later than $e_1$. Because $e_0$'s timestamp is larger than $e'$'s, it must precede or overlap with $e$. Similarlt, $e_1$ must precede or overlap with $e$. Because $e'$ targets an earlier rank than $e_0$, $e_0$'s *slot-refresh phase* must finish after $e'$'s. That means $e_1$ must start after $e'$'s *slot-refresh phase*, because $e_0$ precedes $e_1$. But then, $e_1$ must obtain a timestamp larger than $e'$, which is a contradiction.

  Suppose $e_0$ targets an earlier rank than $e_1$. If $d_1$ finds $e_1$ in the first scan, than in the second scan, $d_1$ would have prioritize $e_0$'s timestamp. Suppose $d_1$ finds $e_1$ in the second scan and during the first scan, it finds $e' != e_1$ and $e'$'s timestamp is larger than $e_1$'s, which is larger than $e_0$'s. Due to how the second scan is defined, $e'$ targets a later rank than $e_1$, which targets a later rank than $e_0$. Because during the second scan, $e_0$ is not chosen, its *slot-refresh phase* must finish after $e'$'s. Because $e_0$ preceds $e_1$, $e_1$ must start after $e'$'s *slot-refresh phase*, so it must obtain a larger timestamp than $e'$, which is a contradiction.

  Therefore, by contradiction, $e_0$ must be matched and $e_0$ matches $d_0$ such that $d_0$ precedes $d_1$.
]

#theorem[In Slotqueue, if a dequeue $d_0$ precedes another dequeue $d_1$, then either:
  - $d_0$ isn't matched.
  - $d_1$ isn't matched.
  - $d_0$ matches $e_0$ and $d_1$ matches $e_1$ such that $e_0$ precedes or overlaps with $e_1$.
] <slotqueue-dequeue-dequeue-theorem>

#proof[
  If either $d_0$ isn't matched or $d_1$ isn't matched, the theorem holds.

  Suppose $d_0$ matches $e_0$ and $d_1$ matches $e_1$.

  If $e_1$ precedes $e_0$, applying @slotqueue-enqueue-enqueue-theorem, we have $e_1$ matches $d_1$ and $e_0$ matches $d_0$ such that $d_1$ precedes $d_0$. This is a contradiction.

  Therefore, $e_0$ either precedes or overlaps with $e_1$.
]

#theorem(
  name: "Linearizability of Slotqueue",
)[Slotqueue is linearizable.] <slotqueue-spsc-linearizability-theorem>

#proof[
  Suppose some history $H$ produced from the Slot-queueu algorithm.

  If $H$ contains some pending method calls, we can just wait for them to complete (because the algorithm is wait-free, which we will prove later). Therefore, now we consider all $H$ to contain only completed method calls. So, we know that if a dequeue or an enqueue in $H$ is matched or not.

  If there are some unmatched enqueues, we can append dequeues sequentially to the end of $H$ until there's no unmatched enqueues. Consider one such $H'$.

  We already have a strict partial order $->$#sub($H'$) on $H'$.

  Because the queue is MPSC, there's already a total order among the dequeues.

  We will extend $->$#sub($H'$) to a strict total order $=>$#sub($H'$) on $H'$ as follows:
  - If $X ->$#sub($H'$)$Y$ then $X =>$#sub($H'$)$Y$. $(1)$
  - If a dequeue $d$ matches $e$ then $e =>$#sub($H'$)$d$. $(2)$
  - If a dequeue $d_0$ matches $e_0$ and another dequeue matches $e_1$ such that $d_0 =>$#sub($H'$)$d_1$ then $e_0 =>$#sub($H'$)$e_1$. $(3)$
  - If a dequeue $d$ overlaps with an enqueue $e$ but does not match $e$, $d =>$#sub($H'$)$e$. $(4)$

  We will prove that $=>$#sub($H'$) is a strict total order on $H'$. That is, for every pair of different method calls $X$ and $Y$, either exactly one of these is true $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ and for any $X$, $X arrow.double.not$#sub($H'$)$X$.

  It's obvious that $X arrow.double.not$#sub($H'$)$X$.

  If $X$ and $Y$ are dequeues, because there's a total order among the dequeues, either exactly one of these is true: $X ->$#sub($H'$)$Y$ or $Y ->$#sub($H'$)$X$. Then due to $(1)$, either $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$. Notice that we cannot obtain $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ from $(2)$, $(3)$, or $(4)$.
  #linebreak()
  Therefore, exactly one of $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ is true. $(*)$

  If $X$ is a dequeue and $Y$ is an enqueue, in this case $(3)$ cannot help us obtain either $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$, so we can disregard it.
  - If $X ->$#sub($H'$)$Y$, then due to $(1)$, $X =>$#sub($H'$)$Y$. By definition, $X$ precedes $Y$, so $(4)$ cannot apply. Applying @slotqueue-dequeue-enqueue-theorem, either
    - $X$ isn't matched, $(2)$ cannot apply. Therefore, $Y arrow.double.not$#sub($H'$)$X$.
    - $X$ matches $e'$ and $e' eq.not Y$. Therefore, $X$ does not match $Y$, or $(2)$ cannot apply. Therefore, $Y arrow.double.not$#sub($H'$)$X$.
    Therefore, in this case, $X arrow.double$#sub($H'$)$Y$ and $Y arrow.double.not$#sub($H'$)$X$.
  - If $Y ->$#sub($H'$)$X$, then due to $(1)$, $Y =>$#sub($H'$)$X$. By definition, $Y$ precedes $X$, so $(4)$ cannot apply. Even if $(2)$ applies, it can only help us obtain $Y =>$#sub($H'$)$X$.
    #linebreak() Therefore, in this case, $Y arrow.double$#sub($H'$)$X$ and $X arrow.double.not$#sub($H'$)$Y$.
  - If $X$ overlaps with $Y$:
    - If $X$ matches $Y$, then due to $(2)$, $Y =>$#sub($H'$)$X$. Because $X$ matches $Y$, $(4)$ cannot apply. Therefore, in this case $Y =>$#sub($H'$)$X$ but $X arrow.double.not$#sub($H'$)$Y$.
    - If $X$ does not match $Y$, then due to $(4)$, $X =>$#sub($H'$)$Y$. Because $X$ doesn't match $Y$, $(2)$ cannot apply. Therefore, in this case $X =>$#sub($H'$)$Y$ but $Y arrow.double.not$#sub($H'$)$X$.
  Therefore, exactly one of $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ is true. $(**)$

  If $X$ is an enqueue and $Y$ is an enqueue, in this case $(2)$ and $(4)$ are irrelevant:
  - If $X ->$#sub($H'$)$Y$, then due to $(1)$, $X =>$#sub($H'$)$Y$. By definition, $X$ precedes $Y$. Applying @slotqueue-enqueue-enqueue-theorem,
    - Both $X$ and $Y$ aren't matched, then $(3)$ cannot apply. Therefore, in this case, $Y arrow.double.not$#sub($H'$)$X$.
    - $X$ is matched but $Y$ is not matched, then $(3)$ cannot apply. Therefore, in this case, $Y arrow.double.not$#sub($H'$)$X$.
    - $X$ matches $d_x$ and $Y$ matches $d_y$ such that $d_x$ precedes $d_y$, then $(3)$ applies and we obtain $X arrow.double$#sub($H'$)$Y$.
    Therefore, in this case, $X arrow.double$#sub($H'$)$Y$ but $Y arrow.double.not$#sub($H'$)$X$.
  - If $Y ->$#sub($H'$)$X$, this case is symmetric to the first case. We obtain $Y arrow.double$#sub($H'$)$X$ but $X arrow.double.not$#sub($H'$)$Y$.
  - If $X$ overlaps with $Y$, because in $H'$, all enqueues are matched, then, $X$ matches $d_x$ and $d_y$. Because $d_x$ either precedes or succeeds $d_y$, Applying $(3)$, we obtain either $X arrow.double$#sub($H'$)$Y$ or $Y arrow.double$#sub($H'$)$X$ and there's no way to obtain the other.
  Therefore, exactly one of $X =>$#sub($H'$)$Y$ or $Y =>$#sub($H'$)$X$ is true. $(***)$

  From $(*)$, $(**)$, $(***)$, we have proved that $=>$#sub($H'$) is a strict total ordering that is consistent with $->$#sub($H'$). In other words, we can order method calls in $H'$ in a sequential manner. We will prove that this sequential order is consistent with FIFO semantics:
  - An enqueue can only be matched by one dequeue: This follows from @slotqueue-unique-match-enqueue.
  - A dequeue can only be matched by one enqueue: This follows from @slotqueue-unique-match-dequeue.
  - The order of item dequeues is the same as the order of item enqueues: Suppose there are two enqueues $e_1$, $e_2$ such that $e_1 arrow.double$#sub($H'$)$e_2$ and suppose they match $d_1$ and $d_2$. Then we have obtained $e_1 arrow.double$#sub($H'$)$e_2$ either because:
    - $(3)$ applies, in this case $d_1 arrow.double$#sub($H'$)$d_2$ is a condition for it to apply.
    - $(1)$ applies, then $e_1$ precedes $e_2$, by @slotqueue-enqueue-enqueue-theorem, $d_1$ must precede $d_2$, thus $d_1 arrow.double$#sub($H'$)$d_2$.
    Therefore, if $e_1 arrow.double$#sub($H'$)$ e_2$ then $d_1 arrow.double$#sub($H'$)$d_2$.
  - An enqueue can only be matched by a later dequeue: Suppose there is an enqueue $e$ matched by $d$. By $(2)$, obviously $e =>$#sub($H'$)$d$.
    - If the queue is empty, dequeues return `false`. Suppose a dequeue $d$ such that any $e arrow.double$#sub($H'$)$d$ is all matched by some $d'$ and $d' arrow.double$#sub($H'$)$d$, we will prove that $d$ is unmatched. By @slotqueue-matching-dequeue-enqueue-theorem, $d$ can only match an enqueue $e_0$ that precedes or overlaps with $d$.
      - If $e_0$ precedes $d$, by our assumption, it's already matched by another dequeue.
      - If $e_0$ overlaps with $d$, by our assumption, $d arrow.double$#sub($H'$)$e_0$ because if $e_0 arrow.double$#sub($H'$)$d$, $e_0$ is already matched by another $d'$. Then, we can only obtain this because $(4)$ applies, but then $d$ does not match $e_0$.
    Therefore, $d$ is unmatched.
  - A dequeue returns `false` when the queue is empty: To put more precisely, for a dequeue $d$, if every successful enqueue $e'$ such that $e' =>$#sub($H'$)$d$ has been matched by $d'$ such that $d' =>$#sub($H'$)$d$, then $d$ would be unmatched and return `false`. Suppose the contrary, $d$ matches $e$. By definition, $e =>$#sub($H'$)$d$. This is a contradiction by our assumption.
  - A dequeue returns `true` and matches an enqueue when the queue is not empty: To put more precisely, for a dequeue $d$, if there exists a successful enqueue $e'$ such that $e' =>$#sub($H'$)$d$ and has not been matched by a dequeue $d'$ such that $d' =>$#sub($H'$)$e'$, then $d$ would be match some $e$ and return `true`. This follows from @slotqueue-unmatched-enqueue-theorem.
  - An enqueue that returns `true` will be matched if there are enough dequeues after that: Based on how @slotqueue-enqueue is defined, when an enqueue returns `true`, it has successfully execute `spsc_enqueue`. By @slotqueue-unmatched-enqueue-theorem, at some point, it would eventually be matched.
  - An enqueue that returns `false` will never be matched: Based on how @slotqueue-enqueue is defined, when an enqueue returns `false`, the state of Slotqueue is not changed, except for the distributed counter. Therefore, it could never be matched.

  In conclusion, $=>$#sub($H'$) is a way we can order method calls in $H'$ sequentially that conforms to FIFO semantics. Therefore, we can also order method calls in $H$ sequentially that conforms to FIFO semantics as we only append dequeues sequentially to the end of $H$ to obtain $H'$.

  We have proved the theorem.
]

=== Progress guarantee

Notice that every loop in Slotqueue is bounded, and no method have to wait for another. Therefore, Slotqueue is wait-free.

=== Performance model
