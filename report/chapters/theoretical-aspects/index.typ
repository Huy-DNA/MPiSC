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

#definition[In an SPSC/MPSC, an `enqueue` operation $e$ is said to *match* a `dequeue` operation $d$ if $d$ returns the value that $e$ enqueues. Similarly, $d$ is said to *match* $e$. In this case, both $e$ and $d$ are said to be *matched*.]

#definition[In an SPSC/MPSC, an `enqueue` operation $e$ is said to be *unmatched* if no `dequeue` operation *matches* it.]

#definition[In an SPSC/MPSC, a `dequeue` operation $d$ is said to be *unmatched* if no `enqueue` operation *matches* it, in other word, $d$ returns `false`.]

== Formalisms

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

#definition[An SPSC is *linearizable* if and only if any history produced from the SPSC that does not have overlapping `dequeue` method calls and overlapping `enqueue` method calls is _linearizable_ according to the following _sequential specification_:
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

#definition[An MPSC is *linearizable* if and only if any history produced from the MPSC that does not have overlapping `dequeue` method calls is _linearizable_ according to the following _sequential specification_:
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

  _An enqueue can only be matched by one dequeue_: Each time an `spsc_dequeue` is executed, it advances the `Last` index. Because only one dequeue can happen at a time, it's guaranteed that each index is only dequeued once. Therefore, an enqueue can only be dequeued at most once.

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

=== ABA problem

=== Memory reclamation

== Theoretical proofs of LTQueueV1

=== Linearizability

=== Progress guarantee

=== ABA problem

=== Memory reclamation

=== Performance model

== Theoretical proofs of LTQueueV2

=== ABA problem

=== Linearizability

=== Progress guarantee

=== Memory reclamation

=== Performance model
