# Berkeley container library

The FastQueue of BCL is used for benchmarking baseline. It supports multiple writes and multiple reads, but reads and writes must be separated by a barrier.

There are some unknown issues (potentially bugs in other parts of the library) when I tried to work with its [FastQueue](https://github.com/Huy-DNA/bcl/blob/5a2a20717b2ca2eb11242bbaa893a2536057594e/bcl/containers/FastQueue.hpp) so I did a simple port of their algorithms here.

I turned FastQueue into a similar MPSC queue, but it's not lock-free.
