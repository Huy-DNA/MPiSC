#let t = toml("/templates.toml")

#let bordered-page(body) = {
  box(width: 100%, height: 100%, stroke: 2pt + black, inset: 1em, body)
}
#show: bordered-page

#set align(center)

#[
  #show: upper
  #set text(size: 15pt)

  *VIETNAM NATIONAL UNIVERSITY HO CHI MINH CITY\
  HO CHI MINH CITY UNIVERSITY OF TECHNOLOGY\
  FACULTY OF COMPUTER SCIENCE AND ENGINEERING*
]

#v(1fr)

#align(center, image("/static/logo.png", height: 5cm))

#[
  #set text(size: 15pt)
  #set align(center)

  *#upper(t.at("course").at("name"))*
]

#v(.5fr)

#set text(weight: "bold", size: 16pt)
STUDYING AND DEVELOPING #linebreak() NONBLOCKING DISTRIBUTED MPSC QUEUES

#set text(weight: "regular", size: 15pt)
Major: Computer Science

#v(1fr)

#set text(weight: "regular", size: 15pt)
#show: upper
#grid(
  columns: (1fr, 1fr),
  rows: (2em, auto),
  column-gutter: .2cm,
  align(right, [*thesis committee*:\ *supervisors*:]),
  align(
    left,
    [
      #t.committee.id\
      #for s in t.at("teachers") [
        #s.at("title")
        #s.at("name")\
      ]
    ],
  ),
)

#v(1fr)
#lower[---oOo---]

#grid(
  columns: (1fr, 1fr),
  rows: (2em, auto),
  column-gutter: .2cm,
  align(right, [*student*:]),
  align(
    left,
    for s in t.at("students") [
      #v(0.5em, weak: true)
      #s.at("name") - #s.at("id")
    ],
  ),
)

#v(1fr)

HCMC, #datetime.today().display("[month]/[year]")
