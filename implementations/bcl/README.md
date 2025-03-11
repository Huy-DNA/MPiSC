# Berkeley container library

Used for benchmarking baseline.

There are some unknown issues (potentially bugs in other parts of the library) when I tried to work with its [FastQueue](https://github.com/Huy-DNA/bcl/blob/5a2a20717b2ca2eb11242bbaa893a2536057594e/bcl/containers/FastQueue.hpp) so I did a simple port of their algorithms here.

The algorithm they used for FastQueue seems flawed to me, so I introduced some correction while still keeping its core ideas.

Disclaimer: I have no intention to make the algorithm lock-free.
