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

    [Number of elements], [Unbounded], [Unbounded], [Unbounded], [Unbounded],
  ),
) <summary-of-MPSCs>

LTQueue @ltqueue is the earliest wait-free shared memory MPSC to our knowledge. This algorithm is wait-free with $O(log n)$ time complexity for both enqueues and dequeues, with $n$ being the number of enqueuers. Their main idea is to split the MPSC among the enqueuers so that each enqueuer maintains a local SPSC data structure, which is only shared with the dequeuer. This improves the MPSC's scalability as multiple enqueues can complete the same time. The enqueuers shared a distributed counter and use it to label each item in their local SPSC with a specific timestamp. The timestamps are organized into nodes of a min-heap-like tree so that the dequeuer can look at the root of tree to determine which local SPSC to dequeue next. The min-heap property of the tree is preserved by a novel wait-free timestamp-refreshing operation. Memory reclamation becomes trivial as each MPSC entry is only shared by one enqueuer and one dequeuer in the local SPSC. The algorithm avoids ABA problem by utilizing load-link/store-conditional (LL/SC). This, on the other hand, presents a challenge in directly porting LTQueue as LL/SC is not widely available as the more popular CAS instruction.

DQueue @dqueue focuses on optimizing performance. It aims to be cache-friendly by having each enqueuer batches their updates in a local buffer to decrease cache misses. It also try to replace expensive atomic instructions such as CAS as many as possible. The MPSC is represented as a linked list of segments (which is an array). To enqueue, the enqueuer reserves a slot in the segment list and enqueues the value into the local buffer. If the local buffer is full, the enqueuer flushes the buffer and writes it onto every reserved slot in the segment list. The producer dequeues the values in the segment list in order, upon encountering a reserved but empty slot, it helps all enqueuers flush their local buffers. For memory reclamation, DQueue utilized a dedicated garbage collection thread that reclaims all fully dequeued segments. However, their algorithm is flawed and a segment maybe freed while some process is holding a reference to it.

WRLQueue @wrlqueue is a lock-free MPSC for embedded real-time system. Its main purpose is to avoid excessive modification of storage space. WRLQueue is simplfy a pair of buffer, one is worked on by multiple enqueuers and the other is work on by the dequeuer. The enqueuers batch their enqueues and write multiple elements onto the buffer once at a time. The dequeuer upon invocation will swap its buffer with the enqueuer's buffers to dequeue from it. However, this requires the dequeuer to wait for all enqueue operations to complete in their buffer. If an enqueue suspends or dies, the dequeuer will have to wait forever, this clearly violates the property of non-blocking.

Jiffy @jiffy is a fast and memory-efficient wait-free MPSC by avoiding excessive allocation of memory. Like DQueue, Jiffy represents the queue as a linked list of segments. Each enqueue reserves a slot in the segment, extends the linked-list as appropriately, writes the value into the slot and sets a per-slot flag to indicate that the slot is ready to be dequeued. To dequeue, the dequeuer repeatedly scan all the slots to find the first-ready-to-be-dequeue slot. Jiffy shows significant good memory usage and throughput compared to other previous state-of-the-art MPMCs.
