= Preliminary results <result>

This section introduces our benchmarking process, including our setup, environment, interested metrics and our microbenchmark program. Most importantly, we showcase the premilinaries results on how well our novel algorithms perform, especially Slotqueue. We conclude this section with a discussion about the implications of these results.

Currently, performance-related properties are of our main focus.

== Benchmarking metrics

This section provides an overview of the metrics we're interested in our algorithms. Performance-wise, latency and throughput are the two most popular metrics. These metrics revolve around the concept of "task". In our context, a task is a single method call of an MPSC queue algorithm, e.g enqueue and dequeue. Note that in our discussion, any two tasks are independent. Roughly speaking, two tasks are independent if one does not need to depend on the output of another for it to finish or there doesn't exist a bigger task that needs to depend on the output of the tasks. This rules out pipeline parallelism, where a task needs to wait for the output of a preceding task, and data parallelism, where a big task is split into and needs to wait for the outputs of multiple smaller tasks.

=== Throughput

Throughput is number of operations finished in a unit of time. Its unit is often given as $"ops"/"s"$ (operations per second), $"ops"/"ms"$ (operations per milliseconds) or $"ops"/"us"$ (operations per microsecond). Intuitively, throughput is closest to our notion of "performance": The higher the throughput, the more tasks are done in a unit of time and thus, the higher the performance. The implication is that our ultimate goal is to optimize the throughput metric of our algorithms.

Nevertheless, as we will see, it's easier to reason about the latency rather the throughput of an algorithm. Additionally, latency has quite an interesting correlation with throughput. Consequently, this makes latency a potentially better metric.

=== Latency

Latency is the time it takes for a single task to complete. Its unit is often given as $"s"/"op"$ (seconds per operation), $"ms"/"op"$ (milliseconds per operation) or $"us"/"op"$ (microseconds per operation).

Intuitively, to optimize latency, one should minimize the number of execution steps required by a task. Therefore, it's obvious that optimizing for latency is much clearer than optimizing for throughput.

In concurrent algorithms, multiple tasks are executed by multiple processes. The key observation is that, if we fix the number of processes, the lower the average latency of a task, the larger the number of tasks that can be completed by a process, which implies a higher throughput. Therefore, a good latency implies a good throughput.

Another key observation is that when the number of processes grows, contention should also grow, thus, causing the average latency to deteriorate. Note that if we manage to keep the average latency of a task fixed while also increasing the number of processes, we gain higher throughput due to higher concurrency. The actionable insight is that if we minimize contention in our algorithms, our algorithm should scale with the number of processes.

Following this discussion, we should aim to discover and optimize out highly contended areas in our algorithms if we want to make them scale well to a large number of nodes/processes.

== Benchmarking setup

== Microbenchmark program

== Benchmark results

== Discussion
