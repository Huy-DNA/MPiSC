
<div align="center">
  <h3>Automatically Generated PDF Documents</h3>
  <p>
    <em>This site hosts the compiled PDF files from the Typst project source files of <a href="https://github.com/Huy-DNA/MPiSC/tree/main">MPiSC</a>.</em>
  </p>
</div>

---

## 📄 Available Documents

<table>
  <thead>
    <tr>
      <th align="left">Document</th>
      <th align="left">Last Content Update</th>
      <th align="center">View</th>
      <th align="center">Download</th>
    </tr>
  </thead>
  <tbody>
      <tr>
        <td><strong>           Studying and developing nonblocking distributed MPSC queues</strong></td>
        <td>2025-05-17</td>
        <td align="center"><a href="report/main.pdf">📕 View</a></td>
        <td align="center"><a href="report/main.pdf" download>⬇️ PDF</a></td>
      </tr>
    </tbody>
  </table>

## 📝 Project Information



### Objective

- Examination of the *shared-memory* literature to find potential *lock-free*, *concurrent*, *multiple-producer single-consumer* queue algorithms.
- Use the new MPI-3 RMA capabilities to port potential lock-free *shared-memory* queue algorithms to distributed context.
- Potentially optimize MPI RMA ports using MPI-3 SHM + C++11 memory model. 

- Minimum required characteristics:

| Dimension           | Desired property        |
| ------------------- | ----------------------- |
| Queue length        | Fixed length            |
| Number of producers | Many                    |
| Number of consumers | One                     |
| Operations          | `queue`, `enqueue`      |
| Concurrency         | Concurrent & Lock-free  |

### Motivation

- Queue is the backbone data structures in many applications: scheduling, event handling, message bufferring. In these applications, the queue may be highly contended, for example, in event handling, there can be multiple sources of events & many consumers of events at the same time. If the queue has not been designed properly, it can become a bottleneck in a highly concurrent environment, adversely affecting the application's scalability. This sentiment also applies to queues in distributed contexts.
- Within the context of shared-memory, there have been plenty of research and testing going into efficient, scalable & lock-free queue algorithms. This presents an opportunity to port these high-quality algorithms to the distributed context, albeit some inherent differences that need to be taken into consideration between the two contexts.
- In the distributed literature, most of the proposed algorithms completely disregard the existing shared-memory algorithms, mostly due to the discrepancy between the programming model of shared memory and that of distributed computing. However, with MPI-3 RMA, the gap is bridged, and we can straightforwardly model shared memory application using MPI. This is why we investigate the porting approach & compare them with existing distributed queue algorithms.

### Approach

The porting approach we choose is to use MPI-3 RMA to port lock-free queue algorithms. We further optimize these ports using MPI SHM (or the so called MPI+MPI hybrid approach) and C++11 for shared memory synchronization.

<details>
  <summary>Why MPI RMA?</summary>
  
  MPSC queue belongs to the class of <i>irregular</i> applications, this means that:
  <ul>
    <li>Memory access pattern is not known.</li>
    <li>Data locations cannot be known in advance, it can change during execution.</li>
  </ul>
  
  In other words, we cannot statically analyze where the data may be stored - data can be stored anywhere and we can only determine its location at runtime. This means the tradition message passing interface using <code>MPI_Send</code> and <code>MPI_Recv</code> is insufficient: Suppose at runtime, process <code>A</code> wants and knows to access a piece of data at <code>B</code>, then <code>A</code> must issue <code>MPI_Recv(B)</code>, but this requires <code>B</code> to anticipate that it should issue <code>MPI_Send(A, data)</code> and know that which data <code>A</code> actually wants. The latter issue can be worked around by having <code>A</code> issue <code>MPI_Send(B, data_descriptor)</code> first. Then, <code>B</code> must have waited for <code>MPI_Recv(A)</code>. However, because the memory access pattern is not known, <code>B</code> must anticipate that any other processes may want to access its data. It's possible but cumbersome.
   
   MPI RMA is specifically designed to conveniently express irregular applications by having one side specify all it wants.

</details>

<details>
  <summary>Why MPI-3 RMA? (<a href="./references/MPI3-RMA/README.md">paper</a>)</summary>

  MPI-3 improves the RMA API, providing the non-collective <code>MPI_Win_lock_all</code> for a process to open an access epoch on a group of processes. This allows for lock-free synchronization.
</details>

<details>
  <summary>Hybrid MPI+MPI (<a href="./references/MPI%2BMPI/README.md">paper</a>)</summary>
  The Pure MPI approach is oblivious to the fact that some MPI processes are on the same node, which causes some unnecessary overhead. MPI-3 introduces the MPI SHM API, allowing us to obtain a communicator containing processes on a single node. From this communicator, we can allocate a shared memory window using <code>MPI_Win_allocate_shared</code>. Hybrid MPI+MPI means that MPI is used for both intra-node and inter-node communication. This shared memory window follows the <em>unified memory model</em> and can be synchronized both using MPI facilities or any other alternatives. Hybrid MPI+MPI can take advantage of the many cores of current computer processors.
</details>

<details>
  <summary>Hybrid MPI+MPI+C++11 (<a href="./references/MPI%2BMPI%2BCpp11/README.md">paper</a>)</summary>
  Within the shared memory window, C++11 synchronization facilities can be used and prove to be much more efficient than MPI. So incorporating C++11 can be thought of as an optimization step for intra-node communication.
</details>

<details>
  <summary>How to perform an MPI port in a lock-free manner?</summary>
  
  With MPI-3 RMA capabilities:
  <ul>
    <li>Use <code>MPI_Win_lock_all</code> and <code>MPI_Win_unlock_all</code> to open and end access epochs.</li>
    <li>Within an access epoch, MPI atomics are used.</li>
  </ul>
  
  This is made clear in [MPI3-RMA](./references/MPI3-RMA/README.md).
</details>

### Literature review

#### Links
- [References](./references/README.md): Notes for various related papers.

#### Known problems
- ABA problem.

  Possible solutions: Monotonic counter, hazard pointer.

- Safe memory reclamation problem.

  Possible solutions: Hazard pointer.

- Special case: empty queue - Concurrent `enqueue` and `dequeue` can conflict with each other.

  Possible solutions: Dummy node to decouple head and tail ([LTQueue](./references/LTQueue/README.md) and [Imp-Lfq](./references/Imp-Lfq/README.md)).

- A slow process performing `enqueue` and `dequeue` could leave the queue in an intermediate state.

  Possible solutions:
  - Help mechanism (introduced in [MSQueue](./references/MSQueue/README.md)): To be lockfree, the other processes can help out patching up the queue (don't wait).

- A dead process performing `enqueue` and `dequeue` could leave the queue broken.
  
  Possible solutions:
  - Help mechanism (introduced in [MSQueue](./references/MSQueue/README.md)): The other processes can help out patching up the queue.

- Motivation for the help mechanism?

  Why: If `enqueue` or `dequeue` needs to perform some updates on the queue to move it to a consistent state, then a suspended process may leave the queue in an intermediate state. The `enqueue` and `dequeue` should not wait until it sees a consistent state or else the algorithm is blocking. Rather, they should help the suspended process complete the operation.

  Solutions often involve (1) detecting intermediate state (2) trying to patch.

  Possible solutions:
  - Typically, updates are performed using CAS. If CAS fails, some state changes have occurred, we can detect if this is intermediary & try to perform another CAS to patch up the queue.
    Note that the patching CAS may fail in case the queue is just patched up, so looping until a successful CAS may not be necessary.
    A good example can be found in [the `enqueue` operation in Imp-Lfq pp.3](./references/Imp-Lfq/README.md)

#### Trends

- Speed up happy paths.
  - The happy path can use lock-free algorithm and fall back to the wait-free algorithm. As lock-free algorithms are typically more efficient, this can lead to speedups.
  - Replacing CAS with simpler operations like FAA, load/store in the fast path ([WFQueue](./references/WFQueue/README.md)).
- Avoid contention: Enqueuers or dequeuers performing on a shared data structures can harm each other's progress.
  - Local buffers can be used at the enqueuers' side in MPSC queue so that enqueuers do not contend with each other.
  - Elimination + Backing off techniques in MPMC.
- Cache-aware solutions.

### Evaluation strategy

We need to evaluate at least 3 levels:
- Theory verification: Prove that the algorithm possesses the desired properties.
- Implementation verification: Even though theory is correct, implementation details nuances can affect the desired properties.
  - Static verification: *Verify* the source code + its dependencies.
  - Dynamic verification: *Verify* its behavior at runtime & *Benchmark*.

#### Correctness
- Linearizability
- No problematic ABA problem
- Memory safety:
  - Safe memory reclamation

#### Performance
- Performance: The less time it takes to serve common workloads on the target platform the better.

#### Lock-freedom
- Lock-freedom: A process suspended while using the queue should not prevent other processes from making progress using the queue.

<details>
  <summary>Caution - Lock-freedom of dependencies</summary>
  A lock-free algorithm often <em>assumes</em> that some synchronization primitive is lock-free. This depends on the target platform and during implementation, the library used. Care must be taken to avoid accidental non-lock-free operation usage.
</details>

#### Scalability
- Scalability: The performance gain for `queue` and `enqueue` should scale with the number of threads on the target platform.


---

<div align="center">
  <p>
    <small>Last build: Sat May 17 05:33:54 UTC 2025</small><br>
    <small>Generated by GitHub Actions • <a href="https://github.com/Huy-DNA/MPiSC/tree/main">View Source</a></small>
  </p>
</div>
