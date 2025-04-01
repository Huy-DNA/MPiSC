= Theoretical aspects <theoretical-aspects>

#import "@preview/lovelace:0.3.0": *
#import "@preview/lemmify:0.1.7": *
#let (
  definition,
  rules: definition-rules,
) = default-theorems("definition", lang: "en")
#let (
  theorem,
  lemma,
  corollary,
  proof,
  rules: theorem-rules,
) = default-theorems("theorem", lang: "en")

#show: theorem-rules
#show: definition-rules

This section discusses the correctness and progress guarantee properties of the distributed MPSC algorithms introduced in @distributed-queues[]. We also provide a theoretical performance model of these algorithms to predict how well they scale to multiple nodes.

== Theoretical proofs of the distributed SPSC

In this section, we focus on the correctness and progress guarantee of the simple distributed SPSC established in @distributed-spsc.

=== Linearizability

We prove that our simple distributed SPSC is linearizable.

#lemma(
  name: [Linearizability of `spsc_enqueue`],
)[The linearization point of `spsc_enqueue` (@spsc-enqueue) is line 5 or line 7.] <spsc-enqueue-linearization-point-lemma>

#proof[ ]

#lemma(
  name: [Linearizability of `spsc_dequeue`],
)[The linearization point of `spsc_dequeue` (@spsc-dequeue) is right after line 19 or line 23.] <spsc-dequeue-linearization-point-lemma>

#proof[ ]

#lemma(
  name: [Linearizability of `spsc_readFront`#sub(`e`)],
)[The linearization point `spsc_readFront`#sub(`e`) (@spsc-enqueue-readFront) is right after line 11, line 14 or line 15.] <spsc-readFront-enqueue-linearization-point-lemma>

#proof[ ]

#lemma(
  name: [Linearizability of `spsc_readFront`#sub(`d`)],
)[The linearization point `spsc_readFront`#sub(`d`) (@spsc-dequeue-readFront) is right after line 11 or right after line 12.] <spsc-readFront-dequeue-linearization-point-lemma>

#proof[ ]

#theorem(
  name: "Linearizability of the simple distributed SPSC",
)[The distributed SPSC given in @distributed-spsc is linearizable.] <slotqueue-spsc-linearizability-lemma>

#proof[This directly follows from @spsc-enqueue-linearization-point-lemma, @spsc-dequeue-linearization-point-lemma, @spsc-readFront-enqueue-linearization-point-lemma, @spsc-readFront-enqueue-linearization-point-lemma.]

=== Progress guarantee

=== ABA problem

=== Memory reclamation

== Theoretical proofs of LTQueueV1

=== Linearizability

=== Progress guarantee

=== ABA problem

=== Memory reclamation

== Theoretical proofs of LTQueueV2

=== ABA problem

=== Linearizability

=== Progress guarantee

=== Memory reclamation

