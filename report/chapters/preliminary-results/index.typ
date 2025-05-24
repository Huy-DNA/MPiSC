= Preliminary results <result>

This section introduces our benchmarking process, including our setup, environment, interested metrics and our microbenchmark program. Most importantly, we showcase the premilinaries results on how well our novel algorithms perform, especially Slotqueue. We conclude this section with a discussion about the implications of these results.

Currently, performance-related properties are of our main focus.

== Benchmarking metrics

This section provides an overview of the metrics we're interested in our algorithms. Performance-wise, latency and throughput are the two most popular metrics. These metrics revolve around the concept of "task". In our context, a task is a single method call of an MPSC queue algorithm, e.g enqueue and dequeue. Note that in our discussion, any two tasks are independent. Roughly speaking, two tasks are independent if one does not need to depend on the output of another for it to finish or there doesn't exist a bigger task that needs to depend on the output of the tasks. This rules out pipeline parallelism, where a task needs to wait for the output of a preceding task, and data parallelism, where a big task is split into and needs to wait for the outputs of multiple smaller tasks.

=== Throughput

Throughput is number of operations finished in a unit of time. Its unit is often given as $"ops"\/"s"$ (operations per second), $"ops"\/"ms"$ (operations per milliseconds) or $"ops"\/"us"$ (operations per microsecond). Intuitively, throughput is closest to our notion of "performance": The higher the throughput, the more tasks are done in a unit of time and thus, the higher the performance. The implication is that our ultimate goal is to optimize the throughput metric of our algorithms.

=== Latency

Latency is the time it takes for a single task to complete. Its unit is often given as $"s"\/"op"$ (seconds per operation), $"ms"\/"op"$ (milliseconds per operation) or $"us"\/"op"$ (microseconds per operation).

Intuitively, to optimize latency, one should minimize the number of execution steps required by a task. Therefore, it's obvious that optimizing for latency is much clearer than optimizing for throughput.

In concurrent algorithms, multiple tasks are executed by multiple processes. The key observation is that, if we fix the number of processes, the lower the average latency of a task, the larger the number of tasks that can be completed by a process, which implies a higher throughput. Therefore, a good latency often (but not always) implies a good throughput.

From the two points above, we can see that latency is a more intuitive metric to optimize for, while being quite indicative of the algorithm's performance.

One question is how to optimize for latency? As we have discussed, we should minimize the number of execution steps. A key observation is that when the number of processes grows, contention should also grow, thus, causing the number of steps taken by a task to grow and thus, the average latency to deterioriate. Note that if we manage to keep the average latency of a task fixed while also increasing the number of processes, we gain higher throughput due to higher concurrency. The actionable insight is that if we minimize contention in our algorithms, our algorithm should scale with the number of processes.

Following this discussion, we should aim to discover and optimize out highly contended areas in our algorithms if we want to make them scale well to a large number of nodes/processes.

== Benchmarking baselines

We use three MPSC queue algorithms as benchmarking baselines:
- dLTQueue + our custom SPSC: Our most optimized version of LTQueue while still keeping the core algorithm in tact.
- Slotqueue + our custom SPSC: Our modification to dLTQueue to obtain a more optimized distributed version of LTQueue.
- AMQueue @amqueue: A hosted bounded MPSC queue algorithm, already detailed in @dmpsc-related-works.

== Microbenchmark program

Our microbenchmark is as follows:
- All processes share a single MPSC, one of the processes is a dequeuer, and the rest are enqueuers.
- The enqueuers enqueue a total of $10^4$ elements.
- The dequeuer dequeue out $10^4$ elements.
- For MPSC, the MPSC is warmed up before the dequeuer starts.

We measure the latency and throughput of the enqueue and dequeue operation. This microbenchmark is repeated 5 times for each algorithm and we take the mean of the results.

== Benchmarking setup

The experiments are carried out on a four-node cluster resided in HPC Lab at Ho Chi Minh University of Technology. Each node is an Intel Xeon CPU e5-2680 v3 with has 8 cores and 16 GB RAM. The interconnect used is Ethernet and so does not support true one-sided communication.

The operating system used is Ubuntu 22.04.5. The MPI implementation used is MPICH version 4.0, released on January 21st, 2022.

We run the producer-consumer microbenchmark on 1 to 4 nodes to measure both the latency and performance of our MPSC algorithms.

== Benchmarking results

#import "@preview/subpar:0.2.2"

@enqueue-benchmark, @dequeue-benchmark and @total-benchmark showcase our benchmarking results, with the y-axis drawin in log scale.

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
  caption: [Microbenchmark results for enqueue operation.],
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
  caption: [Microbenchmark results for dequeue operation.],
  label: <dequeue-benchmark>,
)

#figure(
  image("../../static/images/total_throughput_comparison.png"),
  caption: [Microbenchmark results for total throughput.],
) <total-benchmark>

The most evident thing is that @total-benchmark and @dequeue-throughput-benchmark are almost identical. This backs our claim that in an MPSC queue, the performance is bottlenecked in the dequeuer.

For enqueue latency and throughput, dLTQueue performs far better than dLTQueue while being slightly better than AMQueue. This is in line with our theoretical projection in @summary-of-distributed-mpscs. One concerning trend is that Slotqueue's enqueue throughput seems to degrade with the number of nodes, which signals a potential scalability problem. This is problematic further in that our theoretical model suggests that the cost of enqueue is always fixed. This is to be investigated further in the future.

For dequeue latency and throughput, Slotqueue and AMQueue can quite match each other, while being better than dLTQueue. This is expected, agreeing with our projection of dequeue wrapping overhead in @summary-of-distributed-mpscs. Furthermore, Slotqueue is conceived as a more dequeuer-optimized version of dLTQueue. Based on this empirical result, it's reasonable to believe this is to be the case. Unlike enqueue, dequeue latency of Slotqueue seems to be quite stable, increasing very slowly. Because the dequeuer is the bottleneck of an MPSC, this is a good sign for the scalability of Slotqueue.

In conclusion, based on @total-benchmark, Slotqueue seems to perform better than dLTQueue and AMQueue in terms of both enqueue and dequeue operations, latency-wise and throughput-wise. The overhead of logarithmic-order number of remote operations in dLTQueue seems to be costly, adversely affecting its performance when the number of nodes increases. Additionally, compared to AMQueue, dLTQueue and Slotqueue also have the advantage of fault-tolerance, which due to the blocking nature of AMQueue, cannot be promised.
