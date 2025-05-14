# Jiffy (Dolev Ada, Roy Friedman, 2020) - MPI port

Link: [paper](/references/Jiffy/README.md)

We use bcl for implementation. We intentionally omit memory reclamation in some place for simplicity, as Jiffy doesn't show much potential for porting to distributed environments.

Some part of static checks and compare_and_swap of BCL needs to be patched for this to work.
