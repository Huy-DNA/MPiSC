#let title = [
  Slot-queue - An optimized wait-free distributed MPSC
]

#set document(title: title)

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

= Motivation

A good example of a wait-free MPSC has been presented in @ltqueue. In this paper, the authors propose a novel tree-structure and a min-timestamp scheme that allow both `enqueue` and `dequeue` to be wait-free and always complete in $Theta(log n)$ where $n$ is the number of enqueuers.

We have tried to port this algorithm to distributed context using MPI. The most problematic issue was that the original algorithm uses load-link/store-conditional (LL/SC). To adapt to MPI, we have to propose some modification to the original algorithm to make it use only compare-and-swap (CAS). Even though the resulting algorithm pretty much preserve the original algorithm's characteristic, that is wait-freedom and time complexity of $Theta(log n)$, we have to be aware that this is $Theta(log n)$ remote operations, which is very expensive. We have estimated that for an `enqueue` or a `dequeue` operation in our initial LTQueue version, there are about $2 * log n$ to $10 * log n$ remote operations, depending on data placements and the current state of the LTQueue.

Therefore, to be more suitable for distributed context, we propose a new algorithm that's inspired by LTQueue, in which both `enqueue` and `dequeue` only perform a constant number of remote operations, at the cost of `dequeue` having to perform $Theta(n)$ local operations, where $n$ is the number of enqueuers. Because remote operations are much more expensive, this might be a worthy tradeoff.

= Structure

Each enqueue will have a local SPSC as in LTQueue @ltqueue that supports `dequeue`, `enqueue` and `readFront`. There's a global queue whose entries store the minimum timestamp of the corresponding enqueuer's local SPSC.

#figure(
  image("/assets/structure.png"),
  caption: [Basic structure of slot queue],
)

= Pseudocode

== SPSC

The SPSC of @ltqueue is kept in tact, except that we change it into a circular buffer implementation.

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

The procedures are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`spsc_enqueue(v: data_t)` *returns* `bool`],
  )[
    + *if* `(Last + 1 == First)                        `
      + *return* `false`
    + `Data[Last] = v`
    + `Last = (Last + 1) % Capacity`
    + *return* `true`
  ],
) <slotqueue-spsc-enqueue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 5,
    booktabs: true,
    numbered-title: [`spsc_dequeue()` *returns* `data_t`],
  )[
    + *if* `(First == Last)` *return* $bot$ `             `
    + `res = Data[First]`
    + `First = (First + 1) % Capacity`
    + *return* `res`
  ],
) <slotqueue-spsc-dequeue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 9,
    booktabs: true,
    numbered-title: [`spsc_readFront` *returns* `data_t`],
  )[
    + *if* `(First == Last)                                 `
      + *return* $bot$
    + *return* `Data[First]`
  ],
) <slotqueue-spsc-readFront>

== Slot-queue

The slot-queue types and structures are given as follows:

#pseudocode-list(line-numbering: none)[
  + *Types*
    + `data_t` = The type of data stored
    + `timestamp_t` = `uint64_t`
    + `spsc_t` = The type of the local SPSC
]

#pseudocode-list(line-numbering: none)[
  + *Shared variables*
    + `slots`: An array of `timestamp_t` with the number of entries equal the number of enqueuers
    + `spscs`: An array of `spsc_t` with the number of entries equal the number of enqueuers
    + `counter`: `uint64_t`
]

#pseudocode-list(line-numbering: none)[
  + *Initialization*
    + Initialize all local SPSCs.
    + Initialize `slots` entries to `MAX`.
]

The `enqueue` operations are given as follows:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`enqueue(rank: int, v: data_t)` *returns* `bool`],
  )[
    + `timestamp = FAA(counter)                       `
    + `value = (v, timestamp)`
    + `res = spsc_enqueue(spscs[rank], value)`
    + *if* `(!res)` *return* `false`
    + *if* `(!refreshEnqueue(rank, timestamp))`
      + `refreshEnqueue(rank, timestamp)`
    + *return* `res`
  ],
) <slotqueue-enqueue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 7,
    booktabs: true,
    numbered-title: [`refreshEnqueue(rank: int, ts: timestamp_t)` *returns* `bool`],
  )[
    + `old-timestamp = slots[rank]               `
    + `front = spsc_readFront(spscs[rank])`
    + `new-timestamp = front == `$bot$` ? MAX : front.timestamp`
    + *if* `(new-timestamp != ts)`
      + *return* `true`
    + *return* `CAS(&slots[rank], old-timestamp, new-timestamp)`
  ],
) <slotqueue-refresh-enqueue>

The `dequeue` operations are given as follows:

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 13,
    booktabs: true,
    numbered-title: [`dequeue()` *returns* `data_t`],
  )[
    + `rank = readMinimumRank()                       `
    + *if* `(rank == DUMMY || slots[rank] == MAX)`
      + *return* $bot$
    + `res = spsc_dequeue(spscs[rank])`
    + *if* `(res ==` $bot$`)` *return* $bot$
    + *if* `(!refreshDequeue(rank))`
      + `refreshDequeue(rank)`
    + *return* `res`
  ],
) <slotqueue-dequeue>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 21,
    booktabs: true,
    numbered-title: [`readMinimumRank()` *returns* `int`],
  )[
    + `rank = length(slots)                         `
    + `min-timestamp = MAX`
    + *for* `index` *in* `0..length(slots)`
      + `timestamp = slots[index]`
      + *if* `(min-timestamp < timestamp)`
        + `rank = index`
        + `min-timestamp = timestamp`
    + `old-rank = rank`
    + *for* `index` *in* `0..old-rank`
      + `timestamp = slots[index]`
      + *if* `(min-timestamp < timestamp)`
        + `rank = index`
        + `min-timestamp = timestamp`
    + *return* `rank == length(slots) ? DUMMY : rank`
  ],
) <slotqueue-read-minimum-rank>

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    line-numbering: i => i + 35,
    booktabs: true,
    numbered-title: [`refreshDequeue(rank: int)` *returns* `bool`],
  )[
    + `old-timestamp = slots[rank]`
    + `front = spsc_readFront(spscs[rank])`
    + `new-timestamp = front == `$bot$` ? MAX : front.timestamp`
    + *if* `(front !=` $bot$`)`
      + `slots[rank] = new-timestamp`
      + *return* `true`
    + *return* `CAS(&slots[rank], old-timestamp, new-timestamp)`
  ],
) <slotqueue-refresh-dequeue>

= Linearizability of the local SPSC

In this section, we prove that the local SPSC is linearizable.

#lemma(
  name: [Linearizability of `spsc_enqueue`],
)[The linearization point of `spsc_enqueue` is right after line 2 or right after line 4.] <slotqueue-spsc-enqueue-linearization-point-lemma>

#lemma(
  name: [Linearizability of `spsc_dequeue`],
)[The linearization point of `spsc_dequeue` is right after line 6 or right after line 8.] <slotqueue-spsc-dequeue-linearization-point-lemma>

#lemma(
  name: [Linearizability of `spsc_readFront`],
)[The linearization point `spsc_readFront` is right after line 11 or right after line 12.] <slotqueue-spsc-readFront-linearization-point-lemma>

#theorem(
  name: "Linearizability of local SPSC",
)[The local SPSC is linearizable.] <slotqueue-spsc-linearizability-lemma>

#proof[This directly follows from @slotqueue-spsc-enqueue-linearization-point-lemma, @slotqueue-spsc-dequeue-linearization-point-lemma, @slotqueue-spsc-readFront-linearization-point-lemma.]

= ABA problem

Noticeably, we use no scheme to avoid ABA problem in Slot-queue. In actuality, ABA problem does not adversely affect our algorithm's correctness, except in the extreme case that the 64-bit global counter overflows, which is unlikely.

== ABA-safety

Not every ABA problem is unsafe. We formalize in this section which ABA problem is safe and which is not.

#definition[A *CAS-sequence* on a variable `v` is a sequence of instructions that:
  - Starts with a load $v_0 = $`load(`$v$`)`.
  - Ends with a `CAS(&`$v$`,`$v_0$`,`$v_1$`)`.
]

#definition[A *successful CAS-sequence* on a variable `v` is a *CAS-sequence* on `v` that ends with a successful CAS.]

#definition[A *modification instruction* on a variable `v` is an atomic instruction that may change the value of `v` e.g. a store or a CAS.]

#definition[A *successful modification instruction* on a variable `v` is an atomic instruction that changes the value of `v` e.g. a store or a successful CAS.]

#definition[A *history* of successful *CAS-sequences* and *modification instructions* is a timeline of when any *CAS-sequences* start/end and when any modification instructions end.]

We can define a strict partial order $<$ on the set of *CAS-sequences* and *modification instructions* such that:
- $A < B$ if $A$ and $B$ are both *CAS-sequences* and $A$ ends before $B$ starts.
- $A < B$ if $A$ and $B$ are *modifcation instructions* and $A$ ends before $B$ ends.
- $A < B$ if $A$ is a *modification instruction*, $B$ is a *CAS-sequence* and $A$ ends before $B$ starts.
- $B < A$ if $A$ is a *modification instruction*, $B$ is a *CAS-sequence* and $A$ ends after $B$ ends.

#definition[Consider a history of successful *CAS-sequences* and *modification instructions* on the same variable `v`. *ABA problem* is said to have occurred with `v` if there exists a *successful CAS-sequence* on `v`, during which there's some *successful modification instruction* on `v`.]

#definition[Consider a history of successful *CAS-sequences* and *modification instructions* on the same variable `v`. A history is said to be *ABA-safe* with `v` if and only if:
  - *ABA problem* does not occur with `v` in the history.
  - We can reorder the *successful CAS-sequences* and *modification instructions* in the history such that:
    - No two successful CAS-sequences overlap with each other.
    - No successful modification instruction lies within another successful CAS-sequence.
    - The resulting history after reordering produces the same output as the original history.
]

== Proof of ABA-safety

Notice that we only use `CAS` on:
- Line 13 of `refreshEnqueue` (@slotqueue-refresh-enqueue), or an `enqueue` in general (@slotqueue-enqueue).
- Line 42 of `refreshDequeue` (@slotqueue-refresh-dequeue) or a `dequeue` in general (@slotqueue-dequeue).

Both `CAS` target some slot in the `slots` array.

We apply some domain knowledge of our algorithm to the above formalism.

#definition[A *CAS-sequence* on a slot `s` of an `enqueue` that corresponds to `s` is the sequence of instructions from line 8 to line 13 of its `refreshEnqueue`.]

#definition[A *slot-modification instruction* on a slot `s` of an `enqueue` that corresponds to `s` is line 13 of `refreshEnqueue`.]

#definition[A *CAS-sequence* on a slot `s` of a `dequeue` that corresponds to `s` is the sequence of instructions from line 36 to line 42 of its `refreshDequeue`.]

#definition[A *slot-modification instruction* on a slot `s` of a `dequeue` that corresponds to `s` is line 40 or line 42 of `refreshDequeue`.]

#definition[A *CAS-sequence* of a `dequeue`/`enqueue` is said to *observes a slot value of $s_0$* if it loads $s_0$ at line 8 of `refreshEnqueue` or line 36 of `refreshDequeue`.]

We can now turn to our interested problem in this section.

#lemma(name: "Concurrent accesses on a local SPSC and a slot")[
  Only one dequeuer and one enqueuer can concurrently modify a local SPSC and a slot in the `slots` array.
] <slotqueue-one-enqueuer-one-dequeuer-lemma>

#proof[
  This is trivial to prove based on the algorithm's definition.
]

#lemma(name: "Monotonicity of local SPSC timestamps")[
  Each local SPSC in Slot-queue contains elements with increasing timestamps.
] <slotqueue-spsc-timestamp-monotonicity-theorem>

#proof[
  Each `enqueue` would `FAA` the global counter (line 1 in @slotqueue-enqueue) and enqueue into the local SPSC an item with the timestamp obtained from the counter. Applying @slotqueue-one-enqueuer-one-dequeuer-lemma, we know that items are enqueued one at a time into the SPSC. Therefore, later items are enqueued by later `enqueue`s, which obtain increasing values by `FAA`-ing the shared counter. The theorem holds.
]

#lemma[A `refreshEnqueue` (@slotqueue-refresh-enqueue) can only changes a slot to a value other than `MAX`.] <slotqueue-refresh-enqueue-CAS-to-non-MAX-lemma>

#proof[
  For `refreshEnqueue` to change the slot's value, the condition on line 11 must be false. Then `new-timestamp` must equal to `ts`, which is not `MAX`. It's obvious that the `CAS` on line 13 changes the slot to a value other than `MAX`.
]

#theorem(
  name: [ABA safety of `dequeue`],
)[Assume that the 64-bit global counter never overflows, `dequeue` (@slotqueue-dequeue) is ABA-safe.] <slotqueue-aba-safe-dequeue-theorem>

#proof[
  Consider a *successful CAS-sequence* on slot `s` by a `dequeue` $d$.

  Denote $t_d$ as the value this CAS-sequence observes.

  Due to @slotqueue-one-enqueuer-one-dequeuer-lemma, there can only be at most one `enqueue` at one point in time within $d$.

  If there's no *successful slot-modification instruction* on slot `s` by an `enqueue` $e$ within $d$'s *successful CAS-sequence*, then this `dequeue` is ABA-safe.

  Suppose the `enqueue` $e$ executes the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*. Denote $t_e$ to be the value that $e$ sets `s`.

  If $t_e != t_d$, this CAS-sequence of $d$ cannot be successful, which is a contradiction.

  Therefore, $t_e = t_d$.

  Note that $e$ can only set `s` to the timestamp of the item it enqueues. That means, $e$ must have enqueued a value with timestamp $t_d$. However, by definition, $t_d$ is read before $e$ executes the CAS. This means another process (dequeuer/enqueuer) has seen the value $e$ enqueued and CAS `s` for $e$ before $t_d$. By @slotqueue-one-enqueuer-one-dequeuer-lemma, this "another process" must be another dequeuer $d'$ that precedes $d$.

  Because $d'$ and $d$ cannot overlap, while $e$ overlaps with both $d'$ and $d$, $e$ must be the _first_ `enqueue` on `s` that overlaps with $d$. Combining with @slotqueue-one-enqueuer-one-dequeuer-lemma and the fact that $e$ executes the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*, $e$ must be the only `enqueue` that executes a *successful slot-modification instruction* within $d$'s *successful CAS-sequence*.

  During the start of $d$'s successful CAS-sequence till the end of $e$, `spsc_readFront` on the local SPSC must return the same element, because:
  - There's no other `dequeue`s running during this time.
  - There's no `enqueue` other than $e$ running.
  - The `spsc_enqueue` of $e$ must have completed before the start of $d$'s successful CAS sequence, because a previous dequeuer $d'$ can see its effect.
  Therefore, if we were to move the starting time of $d$'s successful CAS-sequence right after $e$ has ended, we still retain the output of the program because:
  - The CAS sequence only reads two shared values: `slots[rank]` and `spsc_readFront()`, but we have proven that these two values remain the same if we were to move the starting time of $d$'s successful CAS-sequence this way.
  - The CAS sequence does not modify any values except for the last CAS instruction, and the ending time of the CAS sequence is still the same.
  - The CAS sequence modifies `slots[rank]` at the CAS but the target value is the same because inputs and shared values are the same in both cases.

  We have proven that if we move $d$'s successful CAS-sequence to start after the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*, we still retain the program's output.

  The theorem directly follows.
]

#theorem(
  name: [ABA safety of `enqueue`],
)[Assume that the 64-bit global counter never overflows, `enqueue` (@slotqueue-enqueue) is ABA-safe.] <slotqueue-aba-safe-enqueue-theorem>

#proof[
  Consider a *successful CAS-sequence* on slot `s` by an `enqueue` $e$.

  Denote $t_e$ as the value this CAS-sequence observes.

  Due to @slotqueue-one-enqueuer-one-dequeuer-lemma, there can only be at most one `enqueue` at one point in time within $e$.

  If there's no *successful slot-modification instruction* on slot `s` by an `dequeue` $d$ within $e$'s *successful CAS-sequence*, then this `enqueue` is ABA-safe.

  Suppose the `dequeue` $d$ executes the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*. Denote $t_d$ to be the value that $d$ sets `s`.

  If $t_d != t_e$, this CAS-sequence of $e$ cannot be successful, which is a contradiction.

  Therefore, $t_d = t_e$.

  If $t_d = t_e = $ `MAX`, this means $e$ observes a value of `MAX` before $d$ even sets `s` to `MAX`. If this `MAX` value is the initialized value of `s`, it's a contradiction, as `s` must be non-`MAX` at some point for a `dequeue` such as $d$ to run. If this `MAX` value is set by an `enqueue`, it's also a contradiction, as `refreshEnqueue` cannot set a slot to `MAX`. Therefore, this `MAX` value is set by a dequeue $d'$. If $d' equiv.not d$ then it's a contradiction, because between $d'$ and $d$, `s` must be set to be a non-`MAX` value before $d$ can be run. Therefore, $d' equiv d$. But, this means $e$ observes a value set by $d$, which violates our assumption.

  Therefore $t_d = t_e = t' != $ `MAX`. $e$ cannot observe the value $t'$ set by $d$ due to our assumption. Suppose $e$ observes the value $t'$ from `s` set by another enqueue/dequeue call other than $d$.

  If this "another call" is a `dequeue` $d'$ other than $d$, $d'$ precedes $d$. By @slotqueue-spsc-timestamp-monotonicity-theorem, after each `dequeue`, the front element's timestamp will be increasing, therefore, $d'$ must have set `s` to a timestamp smaller than $t_d$. However, $e$ observes $t_e = t_d$. This is a contradiction.

  Therefore, this "another call" is an `enqueue` $e'$ other than $e$, $e'$ precedes $e$. We know that an `enqueue` only sets `s` to the timestamp it obtains. If $e'$ does not overlap with $d$, then after $e'$ has ended, the local SPSC is either empty or has the item $e'$ enqueues as the front element. Therefore, when $d$ runs, it dequeues out the item $e'$ enqueues and set `s` to $t_d$ which is greater than the timestamp of the item $e'$ enqueues. Therefore, $e'$ overlaps with $d$.

  For $e'$ to set `s` to the same value as $d$, $e'$'s `spsc_readFront` must serialize after $d$'s `spsc_dequeue`.

  Because $e'$ and $e$ cannot overlap, while $d$ overlaps with both $e'$ and $e$, $d$ must be the _first_ `dequeue` on `s` that overlaps with $e$. Combining with @slotqueue-one-enqueuer-one-dequeuer-lemma and the fact that $d$ executes the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*, $d$ must be the only `dequeue` that executes a *successful slot-modification instruction* within $e$'s *successful CAS-sequence*.

  During the start of $e$'s successful CAS-sequence till the end of $d$, `spsc_readFront` on the local SPSC must return the same element, because:
  - There's no other `enqueue`s running during this time.
  - There's no `dequeue` other than $d$ running.
  - The `spsc_dequeue` of $d$ must have completed before the start of $e$'s successful CAS sequence, because a previous enqueuer $e'$ can see its effect.
  Therefore, if we were to move the starting time of $e$'s successful CAS-sequence right after $d$ has ended, we still retain the output of the program because:
  - The CAS sequence only reads two shared values: `slots[rank]` and `spsc_readFront()`, but we have proven that these two values remain the same if we were to move the starting time of $e$'s successful CAS-sequence this way.
  - The CAS sequence does not modify any values except for the last CAS/store instruction, and the ending time of the CAS sequence is still the same.
  - The CAS sequence modifies `slots[rank]` at the CAS but the target value is the same because inputs and shared values are the same in both cases.

  We have proven that if we move $e$'s successful CAS-sequence to start after the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*, we still retain the program's output.

  The theorem directly follows.
]

#theorem(
  name: "ABA safety",
)[Assume that the 64-bit global counter never overflows, Slot-queue is ABA-safe.] <aba-safe-slotqueue-theorem>

#proof[
  This follows from @slotqueue-aba-safe-enqueue-theorem and @slotqueue-aba-safe-dequeue-theorem.
]

= Linearizability of Slot-queue

We will prove the linearizability of Slot-queue by pointing out the linearization points of `enqueue` (@slotqueue-enqueue) and `dequeue` (@slotqueue-dequeue).

#lemma(
  name: [Linearizability of `enqueue`],
)[The linearization point of `enqueue` is right after .] <slotqueue-enqueue-linearization-point-lemma>

#lemma(
  name: [Linearizability of `dequeue`],
)[The linearization point of `dequeue` is right after .] <slotqueue-dequeue-linearization-point-lemma>

#theorem(
  name: "Linearizability of Slot-queue",
)[The local SPSC is linearizable.] <slotqueue-spsc-linearizability-lemma>

= Wait-freedom

The algorithm is trvially wait-free as there is no possibilities of infinite loops.

= Memory-safety

The algorithm is memory-safe: No memory deallocation happens and accesses are only made on allocated memory.

#bibliography("/bibliography.yml", title: [References])
