#let t = toml("/templates.toml")

#set text(font: t.fonts.serif, size: 8pt)
#show: block.with(stroke: (top: 1pt), inset: (top: 1em))

#context [
  #if here().page() == 1 {
    return
  }

  #let semester = t.at("semester")
  #let year-from = calc.round(semester / 10) + 2000
  #let year-to = year-from + 1

  #t.at("course").at("name") Report - Semester #semester (#year-from - #year-to)
  #h(1fr)
  Page
  #counter(page).display(
    "1/1",
    both: true,
  )
]
