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
    - No modification instruction lies within another successful CAS-sequence.
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

#proof[ ]

#theorem(
  name: [ABA safety of `enqueue`],
)[Assume that the 64-bit global counter never overflows, `enqueue` (@slotqueue-enqueue) is ABA-safe.] <slotqueue-aba-safe-enqueue-theorem>

#proof[ ]

#theorem(
  name: "ABA safety",
)[Assume that the 64-bit global counter never overflows, Slot-queue is ABA-safe.] <aba-safe-slotqueue-theorem>

#proof[
  This follows from @slotqueue-aba-safe-enqueue-theorem and @slotqueue-aba-safe-dequeue-theorem.
]

= Linearizability of Slot-queue

= Wait-freedom

= Memory-safety

#bibliography("/bibliography.yml", title: [References])
