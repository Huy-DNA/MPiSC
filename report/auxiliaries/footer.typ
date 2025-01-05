#let t = toml("/templates.toml")

#set text(font: t.fonts.serif, size: 8pt)
#show: block.with(stroke: (top: 1pt), inset: (top: 1em))


#context [
  #if here().page() == 1 {
    return
  }

  #let semester = t.at("semester")
  #let semester-of-year = calc.rem(semester, 10)
  // change this if you use this in the 2100s
  #let year-from = calc.round(semester / 10) + 2000
  #let year-to = year-from + 1

  #t.at("course").at("name") Report - Semester #semester-of-year year #year-from - #year-to
  #h(1fr)
  Page
  #counter(page).display(
    "1/1",
    both: true,
  )
]
