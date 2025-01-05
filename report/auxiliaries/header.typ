#let t = toml("/templates.toml")
#set text(font: t.fonts.serif, size: 10pt)
#set par(leading: 0.75em)
#show: block.with(stroke: (bottom: 1pt), inset: (bottom: 0.5em))
#show: upper

#context [
  #if here().page() == 1 {
    return
  }
  #box(image("/static/logo.png", height: 2.5em))
  #h(0.5cm)
  #box[
    HO CHI MINH CITY UNIVERSITY OF TECHNOLOGY\
    FACULTY OF COMPUTER SCIENCE AND ENGINEERING
  ]
  #h(1fr)
]
