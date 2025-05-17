#{ include "./introduction/index.typ" }
#pagebreak()

#{ include "./background/index.typ" }
#pagebreak()

#{ include "./related-works/index.typ" }
#pagebreak()

#{ include "./distributed-queues/index.typ" }
#pagebreak()

#{ include "./preliminary-results/index.typ" }
#pagebreak()

#{ include "./conclusion/index.typ" }
#pagebreak()

#counter(heading).update(0)
#import "@preview/numbly:0.1.0": numbly
#set heading(
  numbering: numbly(
    "Appendix {1:A}",
    "{1:A}.{2}",
    "{1:A}.{2}.{3}",
    "{1:A}.{2}.{3}.{4}",
  ),
)

#{ include "./theoretical-aspects/index.typ" }
#pagebreak()
