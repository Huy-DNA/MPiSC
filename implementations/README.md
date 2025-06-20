# Implementations

This folder holds the implementations of several hand-picked shared memory MPSC algorithms ported to distributed context using MPI RMA.

Porting challenges & strategies are discussed further in these algorithms' folders.

Some have accompanying sections in the typst report to prove their correctness when modification to the original algorithms is necessary.

## Ported algorithms

- [`LTQueue` (Prasad Jayanti & Srdjan Petrovic)](/references/LTQueue/README.md): [implementation](/implementations/ltqueue)

- [`Slotqueue` (custom)](/implementations/slot-queue/README.md): [implementation](/implementations/slot-queue)

## Baselines

- Berkeley container library (bcl): [link](/implementations/bcl)
