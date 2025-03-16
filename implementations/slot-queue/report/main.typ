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
) <spsc-enqueue>

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
) <spsc-dequeue>

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
) <spsc-readFront>

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
    + `timestamp = FFA(counter)                       `
    + `value = (v, timestamp)`
    + `res = spsc_enqueue(spscs[rank], value)`
    + *if* `(!res)` *return* `false`
    + *if* `(!refreshEnqueue(rank, timestamp))`
      + `refreshEnqueue(rank, timestamp)`
    + *return* `res`
  ],
) <enqueue>

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
) <refresh-enqueue>

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
) <dequeue>

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
) <read-minimum-rank>

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
) <refresh-dequeue>

= ABA problem

= Linearizability

= Wait-freedom

= Memory-safety

#bibliography("/bibliography.yml", title: [References])
