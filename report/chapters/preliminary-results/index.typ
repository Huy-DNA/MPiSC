= Preliminary results <result>

This section introduces our benchmarking process, including our setup, environment, interested metrics and our microbenchmark program. Most importantly, we showcase the premilinaries results on how well our novel algorithms perform, especially Slotqueue. We conclude this section with a discussion about the implications of these results.

Currently, performance-related properties are of our main focus.

== Benchmarking metrics

This section provides an overview of the metrics we're interested in our algorithms. Performance-wise, latency and throughput are the two most popular metrics. These metrics revolve around the concept of "task". In our context, a task is a single method call of an MPSC queue algorithm, e.g enqueue and dequeue. Note that in our discussion, any two tasks are independent. Roughly speaking, two tasks are independent if one does not need to depend on the output of another for it to finish or there doesn't exist a bigger task that needs to depend on the output of the tasks. This rules out pipeline parallelism, where a task needs to wait for the output of a preceding task, and data parallelism, where a big task is split into and needs to wait for the outputs of multiple smaller tasks.

=== Throughput

Throughput is number of operations finished in a unit of time. Its unit is often given as $"ops"\/"s"$ (operations per second), $"ops"\/"ms"$ (operations per milliseconds) or $"ops"\/"us"$ (operations per microsecond). Intuitively, throughput is closest to our notion of "performance": The higher the throughput, the more tasks are done in a unit of time and thus, the higher the performance. The implication is that our ultimate goal is to optimize the throughput metric of our algorithms.

Nevertheless, as we will see, it's easier to reason about the latency than the throughput of an algorithm. Additionally, latency has quite an interesting correlation with throughput. Consequently, this makes latency a potentially better metric to optimize for.

=== Latency

Latency is the time it takes for a single task to complete. Its unit is often given as $"s"\/"op"$ (seconds per operation), $"ms"\/"op"$ (milliseconds per operation) or $"us"\/"op"$ (microseconds per operation).

Intuitively, to optimize latency, one should minimize the number of execution steps required by a task. Therefore, it's obvious that optimizing for latency is much clearer than optimizing for throughput.

In concurrent algorithms, multiple tasks are executed by multiple processes. The key observation is that, if we fix the number of processes, the lower the average latency of a task, the larger the number of tasks that can be completed by a process, which implies a higher throughput. Therefore, a good latency implies a good throughput.

From the two points above, we can see that latency is a more intuitive metric to optimize for, while being indicative of the algorithm's performance.

One question is how to optimize for latency? As we have discussed, we should minimize the number of execution steps. A key observation is that when the number of processes grows, contention should also grow, thus, causing the number of steps taken by a task to grow and thus, the average latency to deterioriate. Note that if we manage to keep the average latency of a task fixed while also increasing the number of processes, we gain higher throughput due to higher concurrency. The actionable insight is that if we minimize contention in our algorithms, our algorithm should scale with the number of processes.

Following this discussion, we should aim to discover and optimize out highly contended areas in our algorithms if we want to make them scale well to a large number of nodes/processes.

== Benchmarking baselines

We have two main baselines:
- dLTQueue (@naive-LTQueue): A naively ported shared-memory MPSC queue to distributed environments.
- FastQueue: BCL's MP/MC queue, which is closest to an MPSC we can find in the distributed literature.

Our algorithm Slotqueue (@slotqueue) is compared against these two baselines, in terms of latency and throughput.

Note that as dLTQueue and Slotqueue are MPSC queue wrappers, the underlying SPSC is assumed to be our simple distributed SPSC introduced in @distributed-spsc.

== Microbenchmark program

Our microbenchmark is as follows, aptly named "producer-consumer":
- All processes share a single MPSC (or MP/MC) queue, one of the processes is a dequeuer, and the rest are enqueuers.
- The enqueuers enqueue a total of $10^4$ elements.
- The dequeuer dequeue out $10^4$ elements.
- For MPSC, the MPSC is warmed up before the dequeuer starts. For MP/MC, any enqueuer must finish enqueueing before the dequeuer can start.

We measure the latency and throughput of the enqueue and dequeue operation. This microbenchmark is repeated 5 times for each algorithm and we take the mean of the results.

== Benchmarking setup

The experiments are carried out on a four-node cluster resided in HPC Lab at Ho Chi Minh University of Technology. Each node is an Intel Xeon CPU e5-2680 v3 with has 8 cores and 16 GB RAM. The interconnect used is Ethernet and so does not support true one-sided communication.

The operating system used is Ubuntu 22.04.5. The MPI implementation used is MPICH version 4.0, released on January 21st, 2022.

We run the producer-consumer microbenchmark on 1 to 4 nodes to measure both the latency and performance of our MPSC algorithms.

== Benchmarking results

#import "@preview/subpar:0.2.2"

@enqueue-benchmark and @dequeue-benchmark showcase our benchmarking results.

#subpar.grid(
  figure(
    image("../../static/images/enqueue_latency_comparison.png"),
    caption: [Enqueue latency benchmark results.],
  ),
  <enqueue-latency-benchmark>,
  figure(
    image("../../static/images/enqueue_throughput_comparison.png"),
    caption: [Enqueue throughput benchmark results],
  ),
  <enqueue-throughput-benchmark>,
  columns: (1fr, 1fr),
  caption: [Producer-consumer microbenchmark results for enqueue operation.],
  label: <enqueue-benchmark>,
)

#subpar.grid(
  figure(
    image("../../static/images/dequeue_latency_comparison.png"),
    caption: [Dequeue latency benchmark results.],
  ),
  <dequeue-latency-benchmark>,
  figure(
    image("../../static/images/dequeue_throughput_comparison.png"),
    caption: [Dequeue throughput benchmark results],
  ),
  <dequeue-throughput-benchmark>,
  columns: (1fr, 1fr),
  caption: [Producer-consumer microbenchmark results for dequeue operation.],
  label: <dequeue-benchmark>,
)

The latency and throughput of the enqueue and dequeue operations of dLTQueue, Slotqueue and FastQueue degrade significantly when increasing the number nodes from 1 to 2. This can be explained by the increased overhead introduced by inter-node communication.

The latency and throughput of dLTQueue degrade much faster than Slotqueue and FastQueue. This is in line with our theoretical model that the number of remote operations in dLTQueue increases logarithmically with the number of processes while the others always make a constant number of remote operations. Our Slotqueue algorithm is able to match the performance of FastQueue regarding the enqueue operation. However. Slotqueue performs worse than FastQueue in terms of dequeue operation. This is expected, as our benchmark favors FastQueue, considering that the dequeuer of FastQueue runs completely in isolation, and FastQueue is designed for a more specialized workload (MP/MC rather than MPSC).

One concerning point is that while our theoretical model claims that the enqueue and dequeue methods of Slotqueue always make constant number of remote operations, the latency of enqueue and dequeue of Slotqueue degrade with the number of nodes. This can be attributed to the fact that our cluster uses Ethernet for interconnect, which doesn't support truly one-sided communication between compute nodes and our theoretical model assumes otherwise. Another notable point is that Slotqueue's enqueue operation degrades much faster than dequeue. If the reason of degradation is because of the Ethernet interconnect, then this effect should manifest equally in both enqueue and dequeue operations. The much faster degradation trend in enqueue latency may be due to the fact that one the remote operations of enqueue is on line 14 of @slotqueue-enqueue, which is a fetch-and-add operation to increase the distributed counter. Contention should increase when the number of nodes increases, so this may cause increased overhead with this one remote operation. All of these hypotheses deserve more proper investigation.
