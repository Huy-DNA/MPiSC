= Related works <related-works>

There exists numerous research into the design of lock-free shared memory MPMCs and SPSCs. Interestingly, research into lock-free MPSCs are noticeably scarce. Although in principle, MPMCs and SPSCs can both be adapted for MPSCs use cases, specialized MPSCs can usually yield much more performance. In reality, we have only found 4 papers that are concerned with direct support of lock-free MPSCs: LTQueue @ltqueue, DQueue @dqueue, WRLQueue @wrlqueue and Jiffy @jiffy. @summary-of-MPSCs summarizes the charateristics of these algorithms.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Characteristic summary of existing shared memory MPSCs. The cell marked with (\*) indicates that our evaluation contradicts with the author's claims],
  table(
    columns: (2.5fr, 1fr, 1fr, 1fr, 1fr),
    table.header([*MPSCs*], [*LTQueue*], [*DQueue*], [*WRLQueue*], [*Jiffy*]),
    [ABA solution],
    [Load-link/Store-conditional],
    [Incorrect custom scheme (\*)],
    [Custom scheme],
    [Custom scheme],

    [Memory reclamation],
    [Custom scheme],
    [Incorrect custom scheme (\*)],
    [Custom scheme],
    [Custom scheme],

    [Progress guarantee of dequeue],
    [Wait-free],
    [Wait-free],
    [Blocking (\*)],
    [Wait-free],

    [Progress guarantee of enqueue],
    [Wait-free],
    [Wait-free],
    [Wait-free],
    [Wait-free],
  ),
) <summary-of-MPSCs>

LTQueue @ltqueue is the earliest wait-free shared memory MPSC to our knowledge. This algorithm is wait-free with $O(log n)$ time complexity for both enqueues and dequeues, with $n$ being the number of enqueuers. Their main idea is to split the MPSC among the enqueuers so that each enqueuer maintains a local SPSC data structure, which is only shared with the dequeuer. This improves the MPSC's scalability as multiple enqueues can complete the same time. The enqueuers shared a distributed counter and use it to label each item in their local SPSC with a specific timestamp. The timestamps are organized into nodes of a min-heap-like tree so that the dequeuer can look at the root of tree to determine which local SPSC to dequeue next. The min-heap property of the tree is preserved by a novel wait-free timestamp-refreshing operation. Memory reclamation becomes trivial as each MPSC entry is only shared by one enqueuer and one dequeuer in the local SPSC. The algorithm avoids ABA problem by utilizing load-link/store-conditional (LL/SC). This, on the other hand, presents a challenge in directly porting LTQueue as LL/SC is not widely available as the more popular CAS instruction.

DQueue @dqueue
