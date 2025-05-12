# Slot-queue - A tailor-made optimized and simplified LTQueue for distributed context

This algorithm is inspired by both [Jiffy (Dolev Adas, Roy Friedman, 2022](/references/Jiffy/README.md) and [LTQueue (Prasad Jayanti, Srdjan Petrovic, 2005)](/references/LTQueue/README.md):
  - The shared timestamp and double refresh trick is inspired by LTQueue to help Slot-queue wait-free.
  - The repeated slot scan technique is inspired by Jiffy to help Slot-queue linearizable. However, we optimize it by demonstrating that only 2 scans are needed.
