#let t = toml("/templates.toml")
#let fonts = t.at("fonts")
#show heading: it => {
  it
  v(.5em)
}
#set list(indent: 10pt)

#set par(justify: true)

#set document(
  title: t.title,
  author: t.students.map(s => s.at("name")),
)
#set text(font: fonts.at("serif"), lang: "en", size: 13pt)
#show raw: set text(font: fonts.at("monospace"))
#show raw.where(block: true): set block(
  fill: gray.lighten(90%),
  width: 100%,
  inset: (x: 1em, y: 1em),
)
#show link: it => {
  set text(fill: blue)
  underline(it)
}

#set page(
  paper: "a4",
  header: { include "/auxiliaries/header.typ" },
  footer: { include "/auxiliaries/footer.typ" },
  margin: (top: 20mm, bottom: 20mm, left: 30mm, right: 20mm),
)
#import "@preview/numbly:0.1.0": numbly
#set heading(
  numbering: numbly(
    "Chapter {1:I}:",
    "{1}.{2}",
    "{1}.{2}.{3}",
    "{1}.{2}.{3}.{4}",
  ),
)

#include "/auxiliaries/cover.typ"
#pagebreak()

#include "/auxiliaries/signature.typ"
#pagebreak()

#include "/auxiliaries/disclaimer.typ"
#pagebreak()

#include "/auxiliaries/acknowledgement.typ"
#pagebreak()

#include "/auxiliaries/outline.typ"
#pagebreak()

#include "/chapters/index.typ"

#bibliography("/bibliography.yml", title: [References])
