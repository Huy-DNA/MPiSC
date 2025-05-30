= Related works <related-works>

== Non-blocking shared-memory MPSC queues

There exists numerous research into the design of non-blocking shared memory MPMCs and SPSCs. Interestingly, research into non-blocking MPSC queues are noticeably scarce. Although in principle, MPMC queues and SPSC queues can both be adapted for MPSC queues use cases, specialized MPSC queues can usually yield much more performance. In reality, we have only found 4 papers that are concerned with the direct support of lock-free MPSC queues: LTQueue @ltqueue, DQueue @dqueue, WRLQueue @wrlqueue and Jiffy @jiffy. @summary-of-MPSCs summarizes the charateristics of these algorithms.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Characteristic summary of existing shared memory MPSC queues. The cell marked with (\*) indicates that our evaluation contradicts with the authors' claims.],
  table(
    columns: (1.5fr, 1fr, 1fr, 1fr, 1fr),
    table.header(
      [*MPSC queues*],
      [*LTQueue* @ltqueue],
      [*DQueue* @dqueue],
      [*WRLQueue* @wrlqueue],
      [*Jiffy* @jiffy],
    ),

    [ABA solution],
    [Load-link/Store-conditional],
    [Incorrect custom scheme (\*)],
    [Custom scheme],
    [Custom scheme],

    [Safe memory reclamation],
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

    [Number of elements], [Unbounded], [Unbounded], [Bounded], [Unbounded],
  ),
) <summary-of-MPSCs>

=== LTQueue

To our knowledge, LTQueue @ltqueue is the earliest paper that directly focuses on the design of a wait-free shared memory MPSC queue.

This algorithm is wait-free with $O(log n)$ time complexity for both enqueues and dequeues, with $n$ being the number of enqueuers due to a novel timestamp-update scheme and a tree-structure organization of timestamps.

The basic structure of LTQueue is given in @original-ltqueue-structure. In LTQueue, each enqueuer maintains an SPSC queue that only it and the dequeuer access. This SPSC queue must additionally support the `readFront` operation which returns the front element currently in the SPSC. The SPSC can be any implementations that conform to this interface. In the original paper, the SPSC is represented as a simple linked-list.

The rectangular nodes at the bottom in @original-ltqueue-structure represents an enqueuer, whose SPSC contains items with 2 fields: `value` and `timestamp`. Every enqueuer has to timestamp its data before enqueueing. The timestamps can be obtained using a distributed counter shared by all the enqueuers.

The purpose of timestamping is to determine the order to dequeue the items from the local SPSCs. To efficiently maintain the timestamps and determine which SPSC to dequeue from first, a tree structure with a min-heap property is built upon the enqueuer nodes. The original algorithm leaves the exact representation of the tree open, for example, the arity of the tree, which is shown to be 2 in @original-ltqueue-structure. The circle-shaped nodes in this figure represents the nodes in this tree structure, which are shared by all processes. Each node stores the minimum timestamp along with the owner enqueuer's rank (an identifier given to a process) in the subtree rooted at that node. After every modification to the local SPSC, i.e. after an enqueue and a dequeue, the changes must be propagated up to the root node.

#figure(
  image("/static/images/ltqueue.png"),
  caption: [LTQueue's structure.],
) <original-ltqueue-structure>

To dequeue, the dequeuer simply looks at the root node to determine the rank of the enqueuer to dequeue its SPSC.

The fundamental idea contributes to LTQueue's wait-freedom is the wait-free timestamp-propagation procedure. If there's a change to an enqueuer's SPSC, the timestamp of any nodes that lie on the path from the enqueuer to the root node are refreshed. The timestamp-refreshing procedure is simple:
+ Call load-link on the node's `(timestamp, rank)`.
+ Look at all the timestamps of the node's children and determine the minimum timestamp and its owner rank.
+ Call store-conditional to store the new minimum timestamp and the new owner rank to the current node.
Notice that due to contention, the timestamp-refreshing procedure can fail. In that case, the timestamp-propagation procedure simply retries the timestamp-refreshing procedure one more time. This second call, again, can fail. However, after this second call, the node's timestamp is guaranteed to be up-to-date. The intuition behind this is demonstrated in @original-ltqueue-refresh-correctness. Furthermore, because every node is refreshed at most twice, the timestamp-refresh procedure should finish in a finite number of steps.

#figure(
  image("/static/images/double-refresh.png"),
  caption: [Intuition on how timestamp-refreshing works.],
) <original-ltqueue-refresh-correctness>

The LTQueue algorithm avoids ABA entirely by utilizing load-link/store-conditional. This represents a challenge to directly implementing this algorithm in distributed environment.

The memory reclamation responsibility is handled by the SPSC structure, which is pretty trivial with a custom scheme.

The design of each enqueuer maintaining a separate SPSC allows multiple enqueuer to successfully enqueues its data in parallel without stepping on the others' feet. This can potentially scale well to a large number of processes. However, scalability may be limite due to potentially growing contention during timestamp propagation. The performance of LTQueue in shared-memory environments may still have a lot of room for improvement, i.e. more cache-awareness design, avoiding unnecessary contention, etc. Nevertheless, their timestamp-refreshing scheme is interesting in and out of itself and can potentially inspire the design of new algorithms. In fact, LTQueue's idea is core to one of our optimized distributed MPSC queue algorithm, Slotqueue (@slotqueue).

=== DQueue

DQueue @dqueue focuses on optimizing performance, aiming to be cache-friendly and avoid expensive atomic instructions such as CAS.

The basic structure of DQueue is demonstrated in @original-dqueue-structure.

#figure(
  image("/static/images/dqueue.png"),
  caption: [DQueue's structure.],
) <original-dqueue-structure>

The global queue where data is represented as a linked list of segments. A segment is simply a contiguous array of data items. This design allows for unbounded queue capacity while still allowing a fair degree of random access within a segment. This allows us to use indices to index elements in the queue, thus permitting the use of inexpensive FAA instructions to swing the head and tail indices.

Each enqueuer maintains a local buffer to batch enqueued items before flushing to the global queue. This helps prevent contention and play nice with the cache. To enqueue an item, an enqueuer simply FAA the head index to reserve a slot in the global queue, the obtained index is stored along with the data in the local buffer so that when flushing the local buffer, the enqueuer knows where to write the data into the global queue. Note that while flushing, an index may point to a not-yet-existent slot in the global queue. Therefore, new segments must be allocated on the fly and CAS-ed to the end of the queue.

The dequeuer dequeues the items by looking at the head index. If the queue is not empty but the slot at the head index is empty, the dequeuer utilize a helping mechanism by looking at all enqueuers to help them flush out the local buffer. After this, the head slot is guaranteed to be non-empty and the dequeuer can finally dequeues out this value.

The ABA problem is solved by relying on its safe memory reclamation scheme. In DQueue, CAS is only used to update the tail pointer to point to the newly allocated segment. Therefore, ABA problem in DQueue only involves internal manipulation of pointers to dynamically allocated memory. This means that if a proper memory reclamation scheme is used, ABA problem cannot occur.

DQueue relies on a dedicated garbage collection thread to reclaim segments that have been exhausted by the dequeuer. However, this should be a careful process as even though some segment has been exhausted, some enqueuers can still hold an index that references one these segments. DQueue implements this by reclaming all exhausted segments if there is no enqueuer holding an index referencing these segments. Unfortunately, we believe DQueue's scheme is unsafe. Specifically, as described, DQueue allows the garbage collection thread to reclaim non-adjacent segments in the global queue, without patching any of the next pointers. Any segment just before a reclaimed segment would point to a deallocated next segment. By definition, this segment was not reclaimed because it is referenced by an enqueuer. This means this enqueuer cannot traverse the next pointer chain to get to the end of the queue without accessing an already-deallocated segment.

If adapted to distributed environment, the flushing may be expensive, both from the point-of-view of the enqueuer and the dequeuer. If the dequeuer has to help every enqueuer to flush their local buffer, which should always result in at least one remote operation, the cost would be prohibitively high. Similarly, each flush requires the enqueuer to issue at least one remote operation, but this is at least acceptable as flushing is infrequent.

Still, we can still see that the pattern of maintaining a local buffer inside each enqueuer repeating throughout the literature, which we can definitely apply when designing distributed MPSC queues.

=== WRLQueue

WRLQueue @wrlqueue is a lock-free MPSC queue specifically designed for embedded real-time system. Its main purpose is to avoid excessive modification of storage space.

WRLQueue is simply a pair of buffers, one is worked on by multiple enqueuers and the other is worked on by the dequeuer. The structure of WRLQueue is shown in @original-wrlqueue-structure.

#figure(
  image("/static/images/WRLQueue.png"),
  caption: [WRLQueue's structure.],
) <original-wrlqueue-structure>

The enqueuers batch their enqueues and write multiple elements onto the buffer at once. They use the usual scheme of FFA-ing the tail index (`write_pos` in @original-wrlqueue-structure) to reserve their slots and write data items at their leisure.

The dequeuer upon invocation will swap its buffer with the enqueuer's buffers to dequeue from it, as in @wrlqueue-dequeue-operation. However, WRLQueue explicitly states that the dequeuer has to wait for all enqueue operations to complete in the other buffer before swapping. If an enqueue suspends or dies, the dequeuer will experience a slow-down, this clearly violates the property of non-blocking. Therefore, we believe that WRLQueue is blocking, concerning its dequeue operation.

#figure(
  image("/static/images/WRLQueue-dequeue.png"),
  caption: [WRLQueue's dequeue operation],
) <wrlqueue-dequeue-operation>

=== Jiffy

Jiffy @jiffy is a fast and memory-efficient wait-free MPSC queue by avoiding excessive allocation of memory.

#figure(
  image("/static/images/jiffy.png"),
  caption: [Jiffy's structure.],
) <original-jiffy-structure>

Like DQueue, Jiffy represents the queue as a doubly-linked list of segments as in @original-jiffy-structure. This design again allows Jiffy to be unbounded while using head and tail indices to index elements. Each segment contains a pointer to a dynamically allocated array of slots, instead of directly storing the array. Each slot in the segment contains the data item and a state of that slot (`state_t` in the figure). There are 3 states: `SET`, `EMPTY` and `HANDLED`. Initially, all slots are `EMPTY`. Instead of keeping a global head index, there are per-segment Head indices pointing to the first non-`HANDLED` slot. However, there is still one global Tail index shared by all the processes.

To enqueue, each enqueuer would FAA the Tail to reserve a slot. If the slot isn't in the linked list yet, it tries to allocate new segments and CAS them at the end of the linked list until the slot is available. It then traverses to the desired segment by following the previous pointers starting from the last segment. It then writes the data and sets the slot's state to `SET`. Notice that `EMPTY` slots actually have two substates. If an `EMPTY` slot is before the Tail index, that slot is actually reserved by an enqueuer but has not been set yet, while the `EMPTY` slots after the Tail index are truly empty.

To dequeue, the dequeuer would start from the Head index of the first segment, scanning until it finds the first non-`HANDLED` slot before the end of the queue. If there's no such slot, the queue is empty and the dequeuer would return nothing. If this slot is `SET`, it simply reads the data item in this slot and sets it to `HANDLED`. If this slot is `EMPTY`, that means this slot has been reserved by an enqueuer that hasn't finished. In this case, the dequeuer performs a scan forward to find the first `SET` slot. If not found, the dequeuer returns nothing. Otherwise, it continues to repeatedly scan all slots between the first non-`HANDLED` and the last found `SET` slot until the first `SET` slot between in this interval is unchanged between 2 scans. Only then, the dequeuer would return the data item in this `SET` slot and mark it as `HANDLED`.

Similar to DQueue, CAS is only used when appending new segments at the end of the queue. Therefore, ABA problem only involves internal manipulation of pointers to dynamically-allocated memory. If a proper memory reclamation scheme is utilized.

Regarding memory reclamation, while the dequeuer is scanning the queue, it will reclaim any segments with only `HANDLED` slots. We can see there's potentially a pitfall similar to the one DQueue runs into here. To avoid this pitfall, Jiffy takes the following measures:
- When scanning the queue and the dequeuer sees that a segment contains only `HANDLED` slots, it only reclaims the dynamically-allocated array in the segment, which consumes the most memory, while still keeping the linked-list structure intact. Therefore, if any enqueuer is holding a reference to a segment before the partially-reclaimed segment, it can still traverse the next pointer chain safely.
- To fully reclaim a segment, when partially reclaim a segment, it is added to a garbage list. Note that the first segments that contain only `HANDLED` slots can be fully reclaimed right when the dequeuer performs the scan. When a segment is fully reclaimed, any segment in the garbage list that precedes this segment is also fully reclaimed.

=== Remarks

Out of the 4 investigated MPSC queue algorithms, we quickly eliminate DQueue and WRLQueue as a potential candidate for porting to distributed environment because they either do not provide a sufficient progress guarantee or protection against ABA problem and memory reclamation problem. Jiffy's idea of the dequeuer rescanning the global queue looking for a `SET` slot is quite useful and partly contributes to our idea of double scanning in Slotqueue (@slotqueue), which is our improvement over indefinite repeated scans as in Jiffy. For the time being, due to time constraints, LTQueue remains our primary inspiration and Jiffy will be adapted for distributed environments in the future.

== Distributed MPSC queues <dmpsc-related-works>

This section summarizes to the best of our knowledge existing MPSC queue algorithms, which is reflected in @dmpsc-related-works.

The only paper we have found so far that either mentions directly or indirectly the design of an MPSC queue is @amqueue. @amqueue introduces a hosted blocking (the original paper claims that it's lock-free) bounded distributed MPSC queue called active-message queue (AMQueue) that bares resemblance to WRLQueue in @wrlqueue.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Characteristic summary of existing distributed MPSC queues. #linebreak() $R$ stands for remote operations and $L$ stands for local operations. #linebreak() (\*) @amqueue claims that it's lock-free.],
  table(
    columns: (1fr, 2fr),
    table.header(
      [*FIFO queues*],
      [*Active-message queue (AMQueue) @amqueue*],
    ),

    [Progress guarantee of #linebreak() dequeue], [Blocking (\*)],
    [Progress guarantee of #linebreak() enqueue], [Wait-free],
    [ABA solution], [No compare-and-swap usage],
    [Safe memory reclamation], [Custom scheme],
    [Number of elements], [Bounded],
  ),
) <summary-of-dMPSCs>

The structure of AMQueue is given in @amqueue-structure. The MPSC is split into 2 queues, each maintains its own set of control variables:
- `WriterCnt`: The number of enqueuer currently writing in this queue.
- `Offset`: The index to the first empty entry in the queue.
Note that any shared data and control variables are hosted on the dequeuer.

To determine which queue to read and write, the `QueueNum` binary variable is used. If `QueueNum` is `0`, then the first queue is being actively written by enqueuers and the second queue is being reserved for the dequeuer, and otherwise.

#figure(
  image("/static/images/amqueue.png"),
  caption: [AMQueue's structure.],
) <amqueue-structure>

To enqueue, the enqueuer first reads the `QueueNum` variable to see which of the queue is active. The enqueuer then registers for that queue by atomically FAA-ing the corresponding `WriteCnt` variable. If the fetched value is negative though, the `QueueNum` queue is being swapped for dequeueing and the enqueuer has to decrement the `WriteCnt` variable and repeat the process until `WriteCnt` is positive. After a successful registration, the enqueuer then reserves an entry in the data array by FAA-ing the `Offset` variable. After that, the enqueuer can enqueue data at its leisure. Upon success, the enqueuer has to decrement `WriteCnt` before returning.

To dequeue, the dequeuer inverts `QueueNum` to direct future enqueuers to the other queue. The dequeuer then subtracts a sufficiently large number from `WriterCnt` to signal to other enqueuers that it has started processing. The dequeuer has to wait for all current enqueuers in the queue to finish by repeatedly checking the `WriterCnt` variable, hence the blocking property. After all enqueuers have finished, the dequeuer then batch-dequeues all data in the queue, resets the `Offset` and `WriterCnt` variables to `0`.

AMQueue will serve as a benchmarking baseline for our MPSC queues in @result[].
