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

#definition[A *modification instruction* on a variable `v` is an atomic instruction that may change the value of `v` e.g. a store or a CAS.]

#definition[A *successful modification instruction* on a variable `v` is an atomic instruction that changes the value of `v` e.g. a store or a successful CAS.]

#definition[A *CAS-sequence* on a variable `v` is a sequence of instructions of a method $m$ such that:
  - The first instruction is a load $v_0 = $`load(`$v$`)`.
  - The last instruction is a `CAS(&`$v$`,`$v_0$`,`$v_1$`)`.
  - There's no modification instruction on `v` between the first and the last instruction.
]

#definition[A *successful CAS-sequence* on a variable `v` is a *CAS-sequence* on `v` that ends with a successful CAS.]

#definition[Consider a method $m$ on a concurrent object $S$. $m$ is said to be *ABA-safe* if and only if for any history of method calls produced from $S$, we can reorder any successful CAS-sequences by an invocation of $m$ in the following fashion:
  - If a successful CAS-sequence is part of an invocation of $m$, after reordering, it must still be part of that invocation.
  - If a successful CAS-sequence by an invocation of $m$ precedes another in a method invocation, after reordering, this ordering is still respected.
  - Any successful CAS-sequence by an invocation of $m$ after reordering must not overlap with a successful modification instruction on the same variable.
  - After reordering, all method calls' response events on the concurrent object $S$ stay the same.
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

  Note that $e$ can only set `s` to the timestamp of the item it enqueues. That means, $e$ must have enqueued a value with timestamp $t_d$. However, by definition, $t_d$ is read before $e$ executes the CAS. This means another process (dequeuer/enqueuer) has seen the value $e$ enqueued and CAS `s` for $e$ before $t_d$. By @slotqueue-one-enqueuer-one-dequeuer-lemma, this "another process" must be another dequeuer $d'$ that precedes $d$ because it overlaps with $e$.

  Because $d'$ and $d$ cannot overlap, while $e$ overlaps with both $d'$ and $d$, $e$ must be the _first_ `enqueue` on `s` that overlaps with $d$. Combining with @slotqueue-one-enqueuer-one-dequeuer-lemma and the fact that $e$ executes the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*, $e$ must be the only `enqueue` that executes a *successful slot-modification instruction* on `s` within $d$'s *successful CAS-sequence*.

  During the start of $d$'s successful CAS-sequence till the end of $e$, `spsc_readFront` on the local SPSC must return the same element, because:
  - There's no other `dequeue`s running during this time.
  - There's no `enqueue` other than $e$ running.
  - The `spsc_enqueue` of $e$ must have completed before the start of $d$'s successful CAS sequence, because a previous dequeuer $d'$ can see its effect.
  Therefore, if we were to move the starting time of $d$'s successful CAS-sequence right after $e$ has ended, we still retain the output of the program because:
  - The CAS sequence only reads two shared values: `slots[rank]` and `spsc_readFront()`, but we have proven that these two values remain the same if we were to move the starting time of $d$'s successful CAS-sequence this way.
  - The CAS sequence does not modify any values except for the last CAS instruction, and the ending time of the CAS sequence is still the same.
  - The CAS sequence modifies `slots[rank]` at the CAS but the target value is the same because inputs and shared values are the same in both cases.

  We have proved that if we move $d$'s successful CAS-sequence to start after the _last_ *successful slot-modification instruction* on slot `s` within $d$'s *successful CAS-sequence*, we still retain the program's output.

  If we apply the reordering for every `dequeue`, the theorem directly follows.
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

  If $t_d = t_e = $ `MAX`, this means $e$ observes a value of `MAX` before $d$ even sets `s` to `MAX`. If this `MAX` value is the initialized value of `s`, it's a contradiction, as `s` must be non-`MAX` at some point for a `dequeue` such as $d$ to run. If this `MAX` value is set by an `enqueue`, it's also a contradiction, as `refreshEnqueue` cannot set a slot to `MAX`. Therefore, this `MAX` value is set by a dequeue $d'$. If $d' != d$ then it's a contradiction, because between $d'$ and $d$, `s` must be set to be a non-`MAX` value before $d$ can be run. Therefore, $d' = d$. But, this means $e$ observes a value set by $d$, which violates our assumption.

  Therefore $t_d = t_e = t' != $ `MAX`. $e$ cannot observe the value $t'$ set by $d$ due to our assumption. Suppose $e$ observes the value $t'$ from `s` set by another enqueue/dequeue call other than $d$.

  If this "another call" is a `dequeue` $d'$ other than $d$, $d'$ precedes $d$. By @slotqueue-spsc-timestamp-monotonicity-theorem, after each `dequeue`, the front element's timestamp will be increasing, therefore, $d'$ must have set `s` to a timestamp smaller than $t_d$. However, $e$ observes $t_e = t_d$. This is a contradiction.

  Therefore, this "another call" is an `enqueue` $e'$ other than $e$ and $e'$ precedes $e$. We know that an `enqueue` only sets `s` to the timestamp it obtains.

  Suppose $e'$ does not overlap with $d$. $e'$ can only set `s` to $t'$ if $e'$ sees that the local SPSC has the front element as the element it enqueues. Due to @slotqueue-one-enqueuer-one-dequeuer-lemma, this means $e'$ must observe a local SPSC with only the element it enqueues. Then, when $d$ executes `readFront`, the item $e'$ enqueues must have been dequeued out already, thus, $d$ cannot set `s` to $t'$. This is a contradiction.

  Therefore, $e'$ overlaps with $d$.

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

  We have proved that if we move $e$'s successful CAS-sequence to start after the _last_ *successful slot-modification instruction* on slot `s` within $e$'s *successful CAS-sequence*, we still retain the program's output.

  If we apply the reordering for every `enqueue`, the theorem directly follows.
]

#theorem(
  name: "ABA safety",
)[Assume that the 64-bit global counter never overflows, Slot-queue is ABA-safe.] <aba-safe-slotqueue-theorem>

#proof[
  This follows from @slotqueue-aba-safe-enqueue-theorem and @slotqueue-aba-safe-dequeue-theorem.
]

= Linearizability of Slot-queue

#definition[For an `enqueue` or `dequeue` $o p$, $r a n k(o p)$ is the rank of the enqueuer whose local SPSC is affected by $o p$.]

#definition[For an enqueuer whose rank is $r$, the value stored in its corresponding slot at time $t$ is denoted as $s l o t(r, t)$.]

#definition[For an enqueuer with rank $r$, the minimum timestamp among the elements between `First` and `Last` in its local SPSC at time $t$ is denoted as $m i n \- s p s c \- t s(r, t)$.]

#definition[For an `enqueue`, *slot-refresh phase* refer to its execution of line 5-6 of @slotqueue-enqueue.]

#definition[For a `dequeue`, *slot-refresh phase* refer to its execution of line 19-20 of @slotqueue-dequeue.]

#definition[For a `dequeue`, *slot-scan phase* refer to its execution of line 24-34 of @slotqueue-read-minimum-rank.]

#definition[An `enqueue` operation $e$ is said to *match* a `dequeue` operation $d$ if $d$ returns a timestamp that $e$ enqueues. Similarly, $d$ is said to *match* $e$. In this case, both $e$ and $d$ are said to be *matched*.]

#definition[An `enqueue` operation $e$ is said to be *unmatched* if no `dequeue` operation *matches* it.]

#definition[A `dequeue` operation $d$ is said to be *unmatched* if no `enqueue` operation *matches* it, in other word, $d$ returns $bot$.]

We prove some algorithm-specific results first, which will form the basis for the more fundamental results.

#lemma[If an `enqueue` $e$ begins its *slot-refresh phase* at time $t_0$ and finishes at time $t_1$, there's always at least one successful `refreshEnqueue` or `refreshDequeue` on $r a n k(e)$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$.] <slotqueue-refresh-enqueue-lemma>

#proof[
  If one of the two `refreshEnqueue`s succeeds, then the lemma obviously holds.

  Consider the case where both fail.

  The first `refreshEnqueue` fails because there's another `refreshDequeue` executing its *slot-modification instruction* successfully after $t_0$ but before the end of the first `refreshEnqueue`'s *CAS-sequence*.

  The second `refreshEnqueue` fails because there's another `refreshDequeue` executing its *slot-modification instruction* successfully after $t_0$ but before the end of the second `refreshEnqueue`'s *CAS-sequence*. This another `refreshDequeue` must start its *CAS-sequence* after the end of the first successful `refreshDequeue`, due to @slotqueue-one-enqueuer-one-dequeuer-lemma. In other words, this another `refreshDequeue` starts and successfully ends its *CAS-sequence* between $t_0$ and $t_1$.

  We have proved the theorem.
]

#lemma[If a `dequeue` $d$ begins its *slot-refresh phase* at time $t_0$ and finishes at time $t_1$, there's always at least one successful `refreshEnqueue` or `refreshDequeue` on $r a n k(d)$ starting and ending its *CAS-sequence* between $t_0$ and $t_1$.] <slotqueue-refresh-dequeue-lemma>

#proof[This is similar to the above lemma.]

#lemma[
  Given a rank $r$ and a `dequeue` $d$ that begins its *slot-scan phase* at time $t_0$ and finishes at time $t_1$. If $d$ finds that $s l o t(r, t') = s_0 !=$ `MAX` for some time $t'$ such that $t_0 lt.eq t' lt.eq t_1$, then $s l o t (r, t) = s_0 !=$ `MAX` for any $t$ such that $t' lt.eq t lt.eq t_1$.
] <slotqueue-scan-non-MAX-lemma>

#proof[
  Denote $s_r$ as the slot of rank $r$.

  $s l o t(r, t') = s_0 != $ `MAX` because some processes have executed a successful slot-modification instruction on $s_r$ to set it to $s_0$.

  Take $op$ to be the `enqueue`/`dequeue` that executes the last successful slot-modification instruction on $s_r$ before $t'$. By definition, $op$ set $s_r$ to $s_0$.

  Any `dequeue` before $d$ would have finished before $t_0$, and thus its *slot-fresh phase*. By @slotqueue-refresh-dequeue-lemma, for each `dequeue` before $d$, there must be some successful refresh call whose `spsc_readFront` observes the state of the local SPSC after $d$'s `spsc_dequeue`. By definition, $op$'s refresh call ended after all of these successful refresh call. In the process of proving @aba-safe-slotqueue-theorem, we have proved that the net effect is as if $op$ starts after all of these successful refresh calls. Therefore, $op$ can be treated as if it has seen the local SPSC after any of the previous `dequeue`s' `spsc_dequeue` calls. In other words, $op$ has set $s_r$ to the front element's timestamp after it has observed all previous `spsc_dequeue` before $d$. During $t_0$ to $t_1$, there's no `spsc_dequeue`. Therefore, from after $op$'s successful refresh call until $t_1$, there is no new `spsc_dequeue` that can be observed. Any refresh calls after $op$ until $t_1$ can only observe new `spsc_enqueue`s, but because $op$ set $s_r$ to a non-`MAX` value, their corresponding `refreshEnqueue`s cannot affect $s_r$. Therefore, the lemma holds.
]

#lemma[
  Given a rank $r$ and a `dequeue` $d$ that begins its *slot-scan phase* at time $t_0$ and finishes at time $t_1$. If $d$ finds that $s l o t(r, t') =$ `MAX` for some time $t'$ such that $t_0 lt.eq t' lt.eq t_1$, then $s l o t (r, t) !=$ `MAX` for any $t$ such that $t_0 lt.eq t lt.eq t'$.
] <slotqueue-scan-MAX-lemma>

#proof[
  Because during $d$'s *slot-scan phase*, no other `dequeue` can run and `enqueue`s can only set a slot to non-`MAX`, if $d$ finds that $s l o t(r, t') =$ `MAX` for some time $t'$ such that $t_0 lt.eq t' lt.eq t_1$, then $s l o t (r, t) !=$ `MAX` for any $t$ such that $t_0 lt.eq t lt.eq t'$.

  The theorem holds.
]

We now look at the more fundamental results.

#lemma[
  If $d$ matches $e$, then either $e$ precedes or overlaps with $d$.
] <slotqueue-matching-dequeue-enqueue-lemma>

#proof[
  If $d$ precedes $e$, none of the local SPSCs can contain an item with the timestamp of $e$. Therefore, $d$ cannot return an item with a timestamp of $e$. Thus $d$ cannot match $e$.

  Therefore, $e$ either precedes or overlaps with $d$.
]

#theorem[If an `enqueue` $e$ precedes another `dequeue` $d$, then either:
  - $d$ isn't matched.
  - $d$ matches $e$.
  - $e$ matches $d'$ and $d'$ precedes $d$.
  - $d$ matches $e'$ and $e'$ precedes $e$.
  - $d$ matches $e'$ and $e'$ overlaps with $e$.
] <slotqueue-enqueue-dequeue-theorem>

#proof[

]

#lemma[
  If $d$ matches $e$, then either $e$ precedes or overlaps with $d$.
] <slotqueue-matching-dequeue-enqueue-lemma>

#proof[ ]

#theorem[If a `dequeue` $d$ precedes another `enqueue` $e$, then either:
  - $d$ isn't matched.
  - $d$ matches $e'$ such that $e'$ precedes or overlaps with $e$ and $e' eq.not e$.
] <slotqueue-dequeue-enqueue-theorem>

#proof[ ]

#theorem[If an `enqueue` $e_0$ precedes another `enqueue` $e_1$, then either:
  - Both $e_0$ and $e_1$ aren't matched.
  - $e_0$ is matched but $e_1$ is not matched.
  - $e_0$ matches $d_0$ and $e_1$ matches $d_1$ such that $d_0$ precedes $d_1$.
] <slotqueue-enqueue-enqueue-theorem>

#proof[ ]

#theorem[If a `dequeue` $d_0$ precedes another `dequeue` $d_1$, then either:
  - $d_0$ isn't matched.
  - $d_1$ isn't matched.
  - $d_0$ matches $e_0$ and $d_1$ matches $e_1$ such that $e_0$ precedes or overlaps with $e_1$.
] <slotqueue-dequeue-dequeue-theorem>

#proof[ ]

#theorem(
  name: "Linearizability of Slot-queue",
)[Slot-queue is linearizable.] <slotqueue-spsc-linearizability-lemma>

= Wait-freedom

The algorithm is trivially wait-free as there is no possibility of infinite loops.

= Memory-safety

The algorithm is memory-safe: No memory deallocation happens and accesses are only made on allocated memory.

#bibliography("/bibliography.yml", title: [References])
