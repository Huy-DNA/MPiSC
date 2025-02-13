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
    `timestamp` is of format `[counter, rank]` packed into 64 bits, `rank` is the rank of the MPI enqueuer that obtain the specific value of `counter`.
    

### Pseudo code after removing LL/SC
