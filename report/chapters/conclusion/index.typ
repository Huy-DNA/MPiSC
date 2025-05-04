= Conclusion & Future works <conclusion>

In this thesis, we have looked into the principles of shared-memory programming e.g. the use of atomic operations, to model and design distributed MPSC queue algorithms. We specifically investigate the existing MPSC queue algorithms in the shared memory literature and adapt them for distributed environments using our model. Following this, we have proposed two new distributed MPSC queue algorithms: dLTQueue and Slotqueue. We have proven various interested theoretical aspects of these algorithms, namely, correctness, fault-tolerance and performance. To reflect on what we have obtained theoretically, we have conducted some benchmarks on how queues behave, using another algorithm known as active-message queue (AMQueue) from @amqueue. We have discussed some anomalies discovered via the combined application of theory and epiricism. This lays the foundation for our next steps, which is listed @future-works.

#figure(
  kind: "table",
  supplement: "Table",
  caption: [Future works for the next semester],
  table(
    columns: (1fr, 6fr),
    align: (left, left),
    table.header(
      [*Weeks*],
      [*Work*],
    ),

    [1-3],
    [
      - Adapt Jiffy to distributed environment.
      - Discover optimization opportunities with dLTQueue and Slotqueue.],

    [4-6],
    [- Perform benchmarks on RDMA cluster and investigate the performance degradation problem.],

    [7-9],
    [- Incorporate MPI-3's new support for shared-memory windows and C++11 atomic operations to optimize intra-node communication.],

    [10-12],
    [- Perform more thorough benchmarks and discover more benchmarking baselines for our MPSC queues.],

    [13-15], [- Finalize our results and provide insights from our research.],
  ),
) <future-works>
