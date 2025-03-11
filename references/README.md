# References

## Auxiliaries

In chronological order,

- [Imp-Lfq](./Imp-Lfq/README.md): Implementing lock-free queues

  Cite: Valois, J. D. (1994, October). Implementing lock-free queues. In Proceedings of the seventh international conference on Parallel and Distributed Computing Systems (pp. 64-69).

- [MSQueue](./MSQueue/README.md) (MPMC): Simple, Fast, and Practical Non-Blocking and Blocking Concurrent Queue Algorithms

  Cite: Maged M. Michael and Michael L. Scott. 1996. Simple, fast, and practical non-blocking and blocking concurrent queue algorithms. In Proceedings of the fifteenth annual ACM symposium on Principles of distributed computing (PODC '96). Association for Computing Machinery, New York, NY, USA, 267–275. https://doi.org/10.1145/248052.248106

- [WFQueue](./WFQueue/README.md) (MPMC): A wait-free queue as fast as fetch-and-add

  Cite: Chaoran Yang and John Mellor-Crummey. 2016. A wait-free queue as fast as fetch-and-add. In Proceedings of the 21st ACM SIGPLAN Symposium on Principles and Practice of Parallel Programming (PPoPP '16). Association for Computing Machinery, New York, NY, USA, Article 16, 1–13. https://doi.org/10.1145/2851141.2851168

- [DQueue](./DQueue/README.md) (MPSC): Accelerating Wait-Free Algorithms: Pragmatic Solutions on Cache-Coherent Multicore Architectures

  Cite: Wang, Junchang et al. “Accelerating Wait-Free Algorithms: Pragmatic Solutions on Cache-Coherent Multicore Architectures.” IEEE Access 7 (2019): 74653-74669.

- [Jiffy](./Jiffy/README.md) (MPSC): Jiffy: A Fast, Memory Efficient, Wait-Free Multi-Producers Single-Consumer Queue

  Cite: Dolev Adas and Roy Friedman. 2022. A Fast Wait-Free Multi-Producers Single-Consumer Queue. In Proceedings of the 23rd International Conference on Distributed Computing and Networking (ICDCN '22). Association for Computing Machinery, New York, NY, USA, 77–86. https://doi.org/10.1145/3491003.3491004

- [FFQ](./FFQ/README.md) (SPMC): A fast single-producer/multiple-consumer concurrent FIFO queue.

  Cite: S. Arnautov, P. Felber, C. Fetzer and B. Trach, "FFQ: A Fast Single-Producer/Multiple-Consumer Concurrent FIFO Queue," 2017 IEEE International Parallel and Distributed Processing Symposium (IPDPS), Orlando, FL, USA, 2017, pp. 907-916, doi: 10.1109/IPDPS.2017.41. 

## Relevant algorithms

In chronological order,

- [Lamport queue](./Lamport/README.md) (SPSC): Specifying Concurrent Program Modules 

  Cite: Leslie Lamport. 1983. Specifying Concurrent Program Modules. ACM Trans. Program. Lang. Syst. 5, 2 (April 1983), 190–222. https://doi.org/10.1145/69624.357207

- [LTQueue](./LTQueue/README.md) (MPSC): Logarithmic-Time Single Deleter, Multiple Inserter Wait-Free Queues and Stacks.

  Cite: Jayanti, P., Petrovic, S. (2005). Logarithmic-Time Single Deleter, Multiple Inserter Wait-Free Queues and Stacks. In: Sarukkai, S., Sen, S. (eds) FSTTCS 2005: Foundations of Software Technology and Theoretical Computer Science. FSTTCS 2005. Lecture Notes in Computer Science, vol 3821. Springer, Berlin, Heidelberg. https://doi.org/10.1007/11590156_33.

## Programming models

- [MPI3-RMA](./MPI3-RMA/README.md): An implementation and evaluation of the MPI 3.0 one-sided communication interface

  Cite: James Dinan, Pavan Balaji, Darius Buntinas, David Goodell, William Gropp, and Rajeev Thakur. 2016. An implementation and evaluation of the MPI 3.0 one-sided communication interface. Concurr. Comput. : Pract. Exper. 28, 17 (December 2016), 4385–4404. https://doi.org/10.1002/cpe.3758

- [MPI+MPI](./MPI%2BMPI/README.md): MPI + MPI: a new hybrid approach to parallel programming with MPI plus shared memory

  Cite: Hoefler, T., Dinan, J., Buntinas, D. et al. MPI + MPI: a new hybrid approach to parallel programming with MPI plus shared memory. Computing 95, 1121–1136 (2013). https://doi.org/10.1007/s00607-013-0324-2

- [MPI+MPI+Cpp11](./MPI+MPI+Cpp11/README.md): A novel MPI+MPI hybrid approach combining MPI-3 shared memory windows and C11/C++11 memory model.

  Cite: Lionel Quaranta, Lalith Maddegedara, A novel MPI+MPI hybrid approach combining MPI-3 shared memory windows and C11/C++11 memory model, Journal of Parallel and Distributed Computing, Volume 157, 2021, Pages 125-144, ISSN 0743-7315, https://doi.org/10.1016/j.jpdc.2021.06.008.

## Auxiliaries

- [ABA](./ABA/README.md): Understanding and Effectively Preventing the ABA Problem in Descriptor-based Lock-free Designs

  Cite: Damian Dechev, Peter Pirkelbauer, and Bjarne Stroustrup. 2010. Understanding and Effectively Preventing the ABA Problem in Descriptor-Based Lock-Free Designs. In Proceedings of the 2010 13th IEEE International Symposium on Object/Component/Service-Oriented Real-Time Distributed Computing (ISORC '10). IEEE Computer Society, USA, 185–192. https://doi.org/10.1109/ISORC.2010.10

## Baselines

- [BCL](./BCL/README.md): BCL: A Cross-Platform Distributed Data Structures Library

  Cite: Benjamin Brock, Aydın Buluç, and Katherine Yelick. 2019. BCL: A Cross-Platform Distributed Data Structures Library. In Proceedings of the 48th International Conference on Parallel Processing (ICPP '19). Association for Computing Machinery, New York, NY, USA, Article 102, 1–10. https://doi.org/10.1145/3337821.3337912
