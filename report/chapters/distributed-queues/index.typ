= Distributed MPSCs <distributed-queues>

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

Based on the MPSC algorithms we have surveyed in @related-works[], we propose two wait-free distributed MPSC algorithms:
- One is a direct modification of LTQueue @ltqueue without any usage of LL/SC.
- One is inspired by the timestamp-refreshing idea of LTQueue @ltqueue and repeated-rescan of Jiffy @jiffy. Although it still bears some resemblance to LTQueue, we believe it to be more optimized for distributed context.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Characteristic summary of our proposed distributed MPSCs. $n$ is the number of enqueuers, R stands for *remote operation* and A stands for *atomic operation*],
  table(
    columns: (2fr, 1fr, 1fr),
    table.header(
      [*MPSC*],
      [*LTQueue without LL/SC*],
      [*Optimized distributed LTQueue*],
    ),

    [Correctness], [Linearizable], [Linearizable],
    [Progress guarantee of dequeue], [Wait-free], [Wait-free],
    [Progress guarantee of enqueue], [Wait-free], [Wait-free],
    [Time complexity of dequeue],
    [$O(log n)$ R + $O(log n)$ A],
    [constant R + $O(n)$ A],

    [Time complexity of enqueue],
    [$O(log n)$ R + $O(log n)$ A],
    [constant R + constant A],

    [Number of elements], [Unbounded], [Unbounded],
  ),
) <summary-of-distributed-mpscs>

In this section, we present our proposed distributed MPSCs in detail. Any other discussions about theoretical aspects of these algorithms such as linearizability, progress guarantee, time complexity are deferred to @theoretical-aspects[].

== A basis distributed SPSC

The two algorithms we propose here both utilize a distributed SPSC data structure, which we will present first. For implementation simplicity, we present a bounded SPSC, effectively make our proposed algorithms support only a bounded number of elements. However, one can trivially substitute another distributed unbounded SPSC to make our proposed algorithms support an unbounded number of elements, as long as this SPSC supports the same interface as ours.

#pagebreak()

#columns(2)[
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

  #colbreak()

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
]

The procedures are given as follows.

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  pseudocode-list(
    booktabs: true,
    numbered-title: [`spsc_enqueue(v: data_t)` *returns* `bool`],
  )[
    + *if* `(Last + 1 == First)                                                        `
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
    + *if* `(First == Last)` *return* $bot$ `                                            `
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
    + *if* `(First == Last)                                                    `
      + *return* $bot$
    + *return* `Data[First]`
  ],
) <spsc-readFront>

== Modified LTQueue without LL/SC

== Optimized LTQueue for distributed context
