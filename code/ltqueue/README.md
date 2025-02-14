# LTQueue - MPI port

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

So attaching version tag to `timestamp` is not feasible.

We need to modify this somehow. Another popular approach has to do with pointers: Notice that if we `malloc` a pointer `p`, as long as we do not free `p`, subsequent `malloc` would never produce a value equals to `p`. The idea is to introduce a level of indirection, instead of shared variable = [timestamp | rank], the shared variable is a pointer to [timestamp | rank] and we CAS the pointers instead:
```
old_pointer = svar
old_val = *old_pointer
new_pointer = malloc(size)
*new_pointer = f(old_val)
CAS(svar, old_pointer, new_pointer)
```
If we never free the pointers, ABA never occurs. However, this is apparently unacceptable, we have to free the pointers at some point. This risks introducing the ABA problem & unsafe memory usage: The *safe memory reclamation problem*. This problem can be solved using *harzard pointer*.

### Pseudo code after removing LL/SC
