# Slot-queue - A tailor-made optimized and simplified LTQueue for distributed context

For motivation, please refer to the accompanying report.

This algorithm is inspired by both [Jiffy (Dolev Adas, Roy Friedman, 2022](/references/Jiffy/README.md) and [LTQueue (Prasad Jayanti, Srdjan Petrovic, 2005)](/references/LTQueue/README.md):
  - The shared timestamp and double refresh trick is inspired by LTQueue to help Slot-queue wait-free.
  - The repeated slot scan technique is inspired by Jiffy to help Slot-queue linearizable. However, we optimize it by demonstrating that only 2 scans are needed.

Here's a quick comparison between the original LTQueue, the adapted LTQueue and Slot-queue:

| Criteria | Original LTQueue | Adapted LTQueue | Slot-queue |
|----------|-----------------|----------------|------------|
| Progress guarantee | Wait-free | Wait-free | Wait-free |
| Correctness | Linearizable | Linearizable | Linearizable |
| ABA problem | LL/SC does not have ABA problem | Monotonic tag | No harzardous ABA problem |
| Safe memory reclamation | Specific scheme | Specific scheme | Specific scheme |
| Dequeue time complexity | $O(log n)$ RMOs + $O(log n)$ local ops | $O(log n)$ RMOs + $O(log n)$ local ops | constant RMOs + $O(log n)$ local ops |
| Enqueue time complexity | $O(log n)$ RMOs + $O(log n)$ local ops | $O(log n)$ RMOs + $O(log n)$ local ops | constant RMOs + $O(n)$ local ops |
| Number of elements | Infinite/Finite (depending on the SPSC implementation) | Infinite/Finite (depending on the SPSC implementation) | Infinite/Finite (depending on the SPSC implementation) |
| Dynamic memory allocation | Yes/No (depending on the SPSC implementation) | Yes/No (depending on the SPSC implementation) | Yes/No (depending on the SPSC implementation) |
