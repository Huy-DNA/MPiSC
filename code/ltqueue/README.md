# LTQueue (Prasad Jayanti, Srdjan Petrovic, 2005) - MPI port

Link: [paper](/refs/LTQueue/README.md)

## Naive port 

### Replacing LL/SC

As LL/SC is not supported by MPI, we'll have to replace them using some other supported atomic operations, such as CAS or FAA.

* LL/SC semantics overview ([Wikipedia](https://en.wikipedia.org/wiki/Load-link/store-conditional)):
  - LL/SC is a pair of instructions: Load-link and store-conditional.
  - Load-link returns the current value of a memory location (64 bits assumed).
  - The subsequent store-conditional to the same memory location will store a new value and return true only if no updates have occurred to that location since the load-link.

* Consider this code snippet:
  ```python
  old_val = ll(svar)
  new_val = f(old_val) # new-value-computation time-frame
  sc(location)
  ```
  `sc` will succeed if `location` is not accessed in the time between `ll` and `sc`, even if `location` is written the same value. Therefore, LL/SC allows us to set a location to a new value if it hasn't been accessed since last read.
  
  Ignoring the ABA problem, this should be roughly equivalent:
  ```python
  old_val = location
  new_val = f(old_val) # new-value-computation timeframe
  CAS(location, old_val, new_val)
  ```
  This lies on the assumption that *if a memory location checked at two times is not changed, it hasn't been accessed within this period*. Put it other way, the above sequence allows us to set a location to a new value if its value hasn't changed since last read. Note the difference, and hence, that's why the ABA problem exists for CAS.

  Based on the above observation, if we can ensure that no two accesses within the new-value-computation timeframe set the location to the same value, the CAS sequence will behave like the LL/SC sequence. This follows that we have to restrict the way we update the location.

* However, we need not necessarily replace all LL/SC with CAS. First, we'll have to investigate how LTQueue uses LL/SC:
  - Obtain a timestamp (which could be identical to other concurrently obtained timestamp):
    ```python
    def enqueue(p,v):
        tok = LL(counter) # load the shared monotonic counter
        SC(counter, tok + 1) # try increase the monotonic shared counter
        [...]
    ```
    If we go the same route using a shared monotonic counter, we can just use FAA.
  - Refresh the timestamp of internal nodes:
    ```python
    def refresh():
        LL(currentNodeTimeStamp)
        minT = min([child.timestamp for child in children(currentNode)])
        return SC(currentNodeTimeStamp, minT)
    ```
    `timestamp` is of format `[counter, rank]` packed into 64 bits, `rank` is the rank of the MPI enqueuer that obtains the specific value of `counter`. This is likely to be replaced using CAS.

- Possible replacement schemes:
  1. Replace this LL/SC sequence:
     ```python
     old_val = ll(svar)
     new_val = f(old_val) # new-value-computation time-frame
     sc(location)
     ```
     with this CAS sequence:
     ```python
     old_val = location
     new_val = f(old_val) # new-value-computation timeframe
     CAS(location, old_val, new_val)
     ```
     while ensuring that ABA problem does not occur within a reasonably large timeframe. Some ABA solutions are given in [this paper](/refs/ABA/README.md).
  2. There are some papers that propose more advanced methods to replace LL/SC using CAS. The drawbacks are (1) these also assume shared memory context, which means these require another port (2) potentially too heavyweight.

  We'll investigate first scheme for the time being, which means find a way to avoid ABA problem.
  
#### Avoiding ABA problem

The simplest approach is to use a monotonic version tag: Reserve some bits in the shared variable to use as a monotonic counter, so the shared variable now consists of two parts:
* Control bits: The bits that comprise the meaningful value of the shared variable.
* Counter bits: Represent a monotonic counter.

So, `svar = [Control bits | Counter bits]`. Additionally, `CAS(svar, old value, new value)` becomes `CAS(svar, [old control bits, counter bits], [new control bits, counter bits + 1])`. If overflow of the counter bits does not occur, ABA problem would not occur because the value of the shared variable as a whole is always unique. If overflow does occur, there's a chance that ABA problem occurs, therefore, the larger the counter bits, the less chance the ABA problem occurs. The drawback is that this limits the range of meaningful values for the shared variable.

Can we use version tag for `timestamp`? We know that timestamp is already split into `[counter, rank]`. Using a version tag means that we have to further split the 64 bits:
- `counter` needs to be very large that overflow practically cannot occur.
- `rank` needs to be large enough to represent any cluster.
- `version tag` needs to be large enough to make the chance of ABA very small.

So attaching a version tag to `timestamp` is not feasible. We need to modify this somehow. Another popular approach has to do with pointers: Notice that if we `malloc` a pointer `p`, as long as we do not free `p`, subsequent `malloc` would never produce a value equals to `p`. The idea is to introduce a level of indirection, instead of `svar = [timestamp | rank]`, the `svar` is a pointer to `[timestamp | rank]` and we CAS the pointers instead:
```
old_pointer = svar
old_val = *old_pointer
new_pointer = malloc(size)
*new_pointer = f(old_val)
CAS(svar, old_pointer, new_pointer)
```
If we never free the pointers, ABA never occurs. However, this is apparently unacceptable, we have to free the pointers at some point. This risks introducing the ABA problem & unsafe memory usage: The *safe memory reclamation problem*. This problem can be solved using *harzard pointer*. However, pointers are hard to deal with in distributed computing & hazard pointer is pretty heavyweight.

Coming back to the very nature of [LTQueue](/refs/LTQueue/README.md), we can propose a specialized solution inspired by both the version tag and the idea of introducing a level of indirection.

![image](https://github.com/user-attachments/assets/8f5e0e2c-7ebd-4b87-a06d-7524b193358b)

Notice that, except right in the middle of a dequeue, for a specific `rank`, there's only one corresponding `min-timestamp` in the internal node. How about restructuring the tree like this:

![image](https://github.com/user-attachments/assets/040cea8f-4d21-4597-8b95-5ce3eb84d1eb)

`rank` in this case acts like a pointer - it points to specific min-timestamp in a node with that rank - with one extra benefit: we don't need `malloc` or `free`, so no need for safe memory reclamation.

The ABA problem still remains. However, because `rank` is now a full-flexed 64-bit number, we can just split `rank` into `rank` and `version tag`.

![image](https://github.com/user-attachments/assets/f4500f36-79e2-4729-bb2d-3b5e841500fa)

There's a nuance though. In the original version, the `timestamp` at each internal node is guaranteed to be minimum among the timestamps in the subtree rooted at the internal node (not really, if changes have not been propagated yet). However, with our version, suppose in the above visualization, we dequeue so that the min-timestamp of rank 1 changes and becomes bigger than min-timestamp of rank 2, still, right at that moment, some internal nodes still point to rank 1, implicitly implies that the new min-timestamp of rank 1 is the min-timestamp of the whole subtree, which is incorrect.

Cons:
  - Each time we read the internal node, we have to dereference the rank at the node to access the timestamp. This doubles network activities when accessing the internal node. 

### Pseudo code after removing LL/SC

SPSC is kept intact, and due to Prasad Jayanti and Srdjan Petrovic:

```C
struct node_t
  value_t data
  node_t* next

struct spsc_t
  node_t* first
  node_t* last
  node_t* announce
  node_t* free_later
  value_t help 

function create_spsc()
  q = spsc_t()
  dummy_node = new node_t()
  dummy_node->next = NULL
  q.first = dummy_node
  q.last = dummy_node
  q.announce = NULL
  q.free_later = NULL
  return q

function spsc_enqueue(spsc_t* q, value_t value)
  new_node = new node_t()
  tmp = q->last
  tmp->data = value
  tmp->next = new_node
  last = new_node

function spsc_dequeue(spsc_t* q)
  tmp = q->first
  if (tmp == q->last) return NULL
  retval = tmp->data
  q->help = retval
  q->first = tmp->next
  if (tmp == q->announce)
    tmp' = q->free_later
    q->free_later = q->announce
    free(tmp')
  else free(tmp)
  return retval

function spsc_enqueuer_read_front(spsc_t* q)
  tmp = q->first
  if (tmp == q->last) return NULL
  q->announce = tmp
  if (q->announce != q->first)
    retval = q->help
  else retval = tmp->data
  return retval

function spsc_dequeuer_read_front(spsc_t* q)
  tmp = q->first
  if (tmp == q->last) return NULL
  return tmp->val
```

Modified MPSC after replacing all LL/SC:

```C
struct tree_node_t
  rank_t min_timestamp_rank

struct enqueuer_t
  spsc_t queue
  tree_node_t* tree_node
  timestamp_t min_timestamp

struct mpsc_t
  enqueuer_t enqueuers[ENQUEUERS]
  tree_node_t* root
  int counter

function create_mpsc()
  // logic to build the tree

function mpsc_enqueue(mpsc_t* q, int rank, value_t value)
  timestamp = FAA(q->counter)
  spsc_enqueue(&q->enqueuers[rank].queue, (value, timestamp))
  if (!enqueuer_refresh_timestamp(q, rank))
    enqueuer_refresh_timestamp(q, rank)
  propagate(q, rank)

function mpsc_dequeue(mpsc_t* q)
  rank = q->root->rank.value
  if (rank == NONE) return NULL
  ret = spsc_dequeue(&q->enqueuers[rank].queue)
  if (!dequeuer_refresh_timestamp(q, rank))
    dequeuer_refresh_timestamp(q, rank)
  propagate(q, rank)
  return ret.val

function dequeuer_refresh_timestamp(mpsc_t* q, int rank)
  min_timestamp = spsc_dequeuer_read_front(&q->enqueuers[rank].queue).timestamp
  current_timestamp = q->enqueuers[rank].min_timestamp
  return CAS(&q->enqueuers[rank].min_timestamp, current_timestamp, (min_timestamp, current_timestamp.version + 1))

function enqueuer_refresh_timestamp(mpsc_t* q, int rank)
  min_timestamp = spsc_enqueuer_read_front(&q->enqueuers[rank].queue).timestamp
  current_timestamp = q->enqueuers[rank].min_timestamp
  return CAS(&q->enqueuers[rank].min_timestamp, current_timestamp, (min_timestamp, current_timestamp.version + 1))

function propagate(mpsc_t* q, int rank)
  if (!refresh_self_node(q, rank))
    refresh_self_node(q, rank)
  current_node = q->enqueuers[rank].tree_node
  repeat
    current_node = parent(current_node)
    if (!refresh(q, current_node))
      refresh(q, current_node)
  until (current_node == q->root)

function refresh_self_node(mpsc_t* q, int rank)
  node = q->enqueuers[rank].tree_node
  current_rank = node->min_timestamp_rank
  if (q->enqueuers[rank].min_timestamp.value == MAX_TIMESTAMP)
    return CAS(&node->min_timestamp_rank, current_rank, (NONE, current_rank.version + 1))
  else
    return CAS(&node->min_timestamp_rank, current_rank, (rank, current_rank.version + 1))

function refresh(mpsc_t* q, tree_node_t* node)
  current_rank = current_node->min_timestamp_rank
  min_timestamp = MAX_TIMESTAMP
  min_timestamp_rank = NONE
  for child_node in children(node)
    cur_rank = child_node->min_timestamp_rank.value
    if (cur_rank == NONE) continue
    cur_timestamp = q->enqueuers[cur_rank].min_timestamp.value
    if (cur_timestamp < min_timestamp)
       min_timestamp = cur_timestamp
       min_timestamp_rank = cur_rank
  return CAS(&current_node->min_timestamp_rank, current_rank, (min_timestamp_rank, current_rank.version + 1))
```

#### Linearizability

![image](https://github.com/user-attachments/assets/870c85fb-4d24-4838-98ad-22b68e346079)

Definition 1: We define `TREE` to be the tree constructed by the algorithm.

Definition 2: We define `ROOT` to be the root of `TREE`.

Definition 3: For a node `S` in `TREE`, we define `rank(S, t)` to be the rank that the node `S` holds at time `t`.

Definition 4: For a node `S` in `TREE`, we define `subtree(S)` to be the subtree of `TREE` of which `S` is the root.

Definition 5: For a node `S` in `TREE`, we define `children(S)` to be the set of immediate descendants of `S` in `TREE`.

Definition 6: For a node `S` in `TREE` which is not `ROOT`, we define `parent(S)` to be the parent of `S` in `TREE`.

Definition 7: For an enqueuer `E`, we define `leaf(E)` to be the leaf node that corresponds with the enqueuer `E`.

Definition 8: For a node `S` in `TREE`, we define `path(S)` to be the path from `ROOT` to `S` in `TREE`.

Definition 9: For an enqueuer `E`, we define `path(E)` to be `path(leaf(E))`.

Definition 10: For an enqueuer `E`, we define `timestamp(E, t)` to be the timestamp that `E` holds at time `t`. 

Definition 11: For an enqueuer `E`, we define `min-timestamp-spsc(E, t)` to be the minimum timestamp that the SPSC queue of `E` holds at time `t`.

Definition 12: For a rank `r`, we define `E(r)` to be the enqueuer with rank `r`.

Definition 13: For an enqueuer `E`, we define `rank(E)` to be the rank of `E`.

<details>
  <summary>Theorem 1: For all nodes <code>S</code> in <code>TREE</code>, <code>rank(S, 0) = DUMMY</code>.</summary>
  
  This is straightforward. The algorithm [initializes](https://github.com/Huy-DNA/distributed-mpsc-with-hybrid-mpi/blob/ed00ec4f4cdfd286089f71fe6ce6c19a83285f4f/code/ltqueue/ltqueue.hpp#L803-L805) all the tree nodes to `DUMMY` rank.
</details>

<details>
  <summary>Theorem 2: For all enqueuers <code>E</code>, <code>timestamp(E, 0) = MAX_TIMESTAMP</code>.</summary>

  This is straightforward. The algorithm [initializes](https://github.com/Huy-DNA/distributed-mpsc-with-hybrid-mpi/blob/ed00ec4f4cdfd286089f71fe6ce6c19a83285f4f/code/ltqueue/ltqueue.hpp#L391) all the enqueuers' timestamps to `MAX_TIMESTAMP`.
</details>


<details>
  <summary>Theorem 3: For all enqueuers <code>E</code>, its timestamp is ever changed by <code>enqueuer_refresh_timestamp</code> and <code>dequeuer_refresh_timestamp</code>. Only one <code>enqueuer_refresh_timestamp</code> and <code>dequeuer_refresh_timestamp</code> can run at a time.</summary>

  This is straightforward. Only the enqueuer `E` can call `enqueuer_refresh_timestamp` to update its timestamp, and only the dequeuer can call `dequeuer_refresh_timestamp` on `E` to update `E`'stimestamp.
</details>

<details>
  <summary>Theorem 4: For an enqueuer <code>E</code>, during an <code>mpsc_enqueue</code> call, if <code>spsc_enqueue</code> completes at time t0, the two <code>enqueuer_refresh_timestamp</code> calls complete at time <code>t1</code>, <code>timestamp(E, t1) = min-timestamp-spsc(E, t2)</code> where <code>t2 > t0</code>. Similarly, for an enqueuer <code>E</code>, during an <code>mpsc_dequeue</code> call targeted at <code>E</code>, if <code>spsc_dequeue</code> completes at time <code>t0'</code>, the two <code>dequeuer_refresh_timestamp</code> calls complete at time <code>t1'</code>, <code>timestamp(E, t1') = min-timestamp-spsc(E, t2')</code> where <code>t2' > t0'</code>.</summary>


  What `enqueuer_refresh_timestamp` does:
  1. Get the current minimum timestamp of the SPSC of `E`, or `min-timestamp-spsc(E, t')` with `t' > t0`.
  2. Get the current timestamp of `E`, or `timestamp(E, t'')` with `t'' > t' > t0`.
  3. If the timestamp of `E` hasn't change since step 2, then `timestamp(E, t''') = min-timestamp-spsc(E, t')` with `t''' > t'' > t' > t0` and return true. Otherwise, return false.


  What `dequeuer_refresh_timestamp` does:
  1. Get the current minimum timestamp of the SPSC of `E`, or `min-timestamp-spsc(E, t')` with `t' > t0`.
  2. Get the current timestamp of `E`, or `timestamp(E, t'')` with `t'' > t' > t0`.
  3. If the timestamp of `E` hasn't change since step 2, then `timestamp(E, t''') = min-timestamp-spsc(E, t')` with `t''' > t'' > t' > t0` and return true. Otherwise, return false.

  If the first `enqueuer_refresh_timestamp` succeeds, then `timestamp(E, t''') = min-timestamp-spsc(E, t')` with `t''' > t'' > t' > t0`, and because `t1 > t'''`, either `timestamp(E, t1) = timestamp(E, t''')` or `timestamp(E, T1) = min-timestamp-spsc(E, t'''')` with `t'''' > t > t0'` due to being updated by `dequeuer_refresh_timestamp`. Anyways, the statement that `timestamp(E, t1) = min-timestamp-spsc(E, t2)` where `t2 > t0` holds.
  
  If the first `enqueuer_refresh_timestamp` fails, that means due to theorem 3, `dequeuer_refresh_timestamp` has changed it somewhere between step 2 and step 3. We retry `enqueuer_refresh_timestamp` again. If it succeeds, the previous argument still holds. If it fails again. It means another `dequeuer_refresh_timestamp` has changed it between step 2 and step 3 of the second trial. However, this `dequeuer_refresh_timestamp` must have read the the minimum timestamp of `E`'s SPSC after step 2 of the first trial (because only one dequeue is allowed to run at a time), which means it saw that minimum timestamp after `t0` and update the timestamp of `E` to be so.  Therefore,  the statement that `timestamp(E, t1) = min-timestamp-spsc(E, t2)` where `t2 > t0` holds.

  The same line of arguments holds for `dequeuer_refresh_timestamp`.
</details>

<details>
  <summary>Theorem 5: For an enqueuer <code>E</code>, during an <code>mpsc_enqueue</code> call starting at <code>t0</code> and ending at <code>t2></code>, if the `spsc_enqueue` completes at time <code>t1</code> and no <code>mpsc_dequeue</code> has been running between <code>t0</code> and <code>t2</code>, for all nodes in <code>S</code> in <code>TREE</code>, <code>rank(S, t2) = rank(E_S)</code> where <code>min-timestamp-spsc(E_S, t') <= min-timestamp-spsc(E, t')</code> for all <code>E</code> in <code>subtree(S0)</code> and some <code>t' >= t1</code>. </summary>
</details>

<details>
  <summary>Theorem 6: During an <code>mpsc_dequeue</code> at the enqueuer <code>E</code> starting at <code>t0</code> and ending at <code>t2</code>, at any time <code>t0 <= t1 <= t2</code>, for all nodes in <code>S</code> in <code>TREE</code> and not in `path(E)`, <code>rank(S, t1) = rank(E_S)</code> where <code>min-timestamp-spsc(E_S, t') <= min-timestamp-spsc(E, t')</code> for all <code>E</code> in <code>subtree(S0)</code> and some <code>t1 >= t' >= t0</code>.
</details>

<details>
  <summary>Theorem 7: After an <code>mpsc_dequeue</code> at the enqueuer <code>E</code> starting at <code>t0</code> and ending at <code>t2</code>, if the `<code>spsc_dequeue</code> completes at time <code>t1</code>, for all nodes in <code>S</code> in <code>TREE</code>, <code>rank(S, t2) = rank(E_S)</code> where <code>min-timestamp-spsc(E_S, t') <= min-timestamp-spsc(E, t')</code> for all <code>E</code> in <code>subtree(S0)</code> and some <code>t' >= t1</code>.
</details>

#### ABA problem

ABA is unlikely to occur because every place we use `CAS`, we increase the version tag.

#### Safe memory reclamation

This is safe as proven in the original paper.

#### Lockfree-ness

This is trivial.

### Porting

See [source code](./ltqueue.hpp).

For the time being, SPSC is implemented using a circular array instead of a linked list due to the complexity of managing dynamic memory in the shared memory window with MPI.
