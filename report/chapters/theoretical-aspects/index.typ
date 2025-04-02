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

This section discusses the correctness and progress guarantee properties of the distributed MPSC algorithms introduced in @distributed-queues[]. We also provide a theoretical performance model of these algorithms to predict how well they scale to multiple nodes.

== Terminology

In this section, we introduce some terminology that we will use throughout our proofs.

#definition[In an SPSC/MPSC, an enqueue operation $e$ is said to *match* a dequeue operation $d$ if $d$ returns the value that $e$ enqueues. Similarly, $d$ is said to *match* $e$. In this case, both $e$ and $d$ are said to be *matched*.]

#definition[In an SPSC/MPSC, an enqueue operation $e$ is said to be *unmatched* if no dequeue operation *matches* it.]

#definition[In an SPSC/MPSC, a dequeue operation $d$ is said to be *unmatched* if no enqueue operation *matches* it, in other word, $d$ returns `false`.]

== Formalization

In this section, we formalize the notion of correct concurrent algorithms and harmless ABA problem. We will base our proofs on these formalisms to prove their correctness.

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
  - A dequeue returns `true` and matches an enqueue when the queue is not empty
  - An enqueue returns `false` when the queue is full.
  - An enqueue would return `true` when the queue is not full and the number of elements should increase by one.
  - A read-front would return `false` when the queue is empty.
  - A read-front would return `true` and the first element in the queue is read out.
] <linearizable-spsc>

==== Linearizable MPSC

An MPSC supports 2 methods:
- `enqueue` which accepts an input parameter and returns a boolean.
- `dequeue` which accepts an output parameter and returns a boolean.

#definition[An MPSC is *linearizable* if and only if any history produced from the MPSC that does not have overlapping dequeue method calls is _linearizable_ according to the following _sequential specification_:
  - An enqueue can only be matched by one dequeue.
  - A dequeue can only be matched by one enqueue.
  - The order of item dequeues is the same as the order of item enqueues.
  - An enqueue can only be matched by a later dequeue.
  - A dequeue returns `false` when the queue is empty.
  - A dequeue returns `true` and matches an enqueue when the queue is not empty
  - An enqueue returns `false` when the queue is full.
  - An enqueue would return `true` when the queue is not full and the number of elements should increase by one.
] <linearizable-mpsc>

=== ABA-safety

Not every ABA problem is unsafe. We formalize in this section which ABA problem is safe and which is not.

#definition[A *modification instruction* on a variable `v` is an atomic instruction that may change the value of `v` e.g. a store or a CAS.]

#definition[A *successful modification instruction* on a variable `v` is an atomic instruction that changes the value of `v` e.g. a store or a successful CAS.]

#definition[A *CAS-sequence* on a variable `v` is a sequence of instructions of a method $m$ such that:
  - The first instruction is a load $v_0 = $`load(`$v$`)`.
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

== Theoretical proofs of the distributed SPSC

In this section, we focus on the correctness and progress guarantee of the simple distributed SPSC established in @distributed-spsc.

=== Linearizability

We prove that our simple distributed SPSC is linearizable.

#theorem(
  name: "Linearizability of the simple distributed SPSC",
)[The distributed SPSC given in @distributed-spsc is linearizable.] <spsc-linearizability-lemma>

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

=== ABA problem

There's no CAS instruction in our simple distributed SPSC, so there's no potential for ABA problem.

=== Memory reclamation

There's no dynamic memory allocation and deallocation in our simple distributed SPSC, so it is memory-safe.

== Theoretical proofs of LTQueueV1

=== Notation

The structure of LTQueueV1 is presented again in @remind-modified-ltqueue-tree.

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
        LTQueueV1's structure
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

=== ABA problem

We use CAS instructions on:
- Line 34 and line 36 of `refreshTimestamp`#sub(`e`) (@ltqueue-enqueue-refresh-timestamp).
- Line 52 of `refreshNode`#sub(`e`) (@ltqueue-enqueue-refresh-node).
- Line 60 of `refreshLeaf`#sub(`e`) (@ltqueue-enqueue-refresh-leaf).
- Line 88 and line 90 of `refreshTimestamp`#sub(`d`) (@ltqueue-dequeue-refresh-timestamp).
- Line 106 of `refreshNode`#sub(`d`) (@ltqueue-dequeue-refresh-node).
- Line 114 of `refreshLeaf`#sub(`e`) (@ltqueue-dequeue-refresh-leaf).

Notice that at these locations, we increase the associated version tags of the CAS-ed values. These version tags are 32-bit in size, therefore, practically, ABA problem can't virtually occur. It's safe to assume that there's no ABA problem in LTQueueV1.

=== Linearizability

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

=== Progress guarantee

=== Memory reclamation

=== Performance model

== Theoretical proofs of LTQueueV2

=== ABA problem

=== Linearizability

=== Progress guarantee

=== Memory reclamation

=== Performance model
