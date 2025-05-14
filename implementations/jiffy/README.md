# Jiffy (Dolev Ada, Roy Friedman, 2020) - MPI port

Link: [paper](/references/Jiffy/README.md)

This version is bounded, and enqueue is a partial function.

We use a circular array hosted on the dequeuer for simplicity.

Remark: I personally found that existing solutions to distributed dynamic memory allocator unsatisfactory for general use cases, specifically in the realm of MPI. Need more investigation.
