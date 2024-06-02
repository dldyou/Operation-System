#let team_name = "dldyou"
#let title = "운영체제 기말 정리본"
#let sub_title = "2024-1"
#let authors = (
  team_name,
)

#let head = {
  [
    #text(weight: 700)[#team_name]
    #text(weight: 400)[#sub_title]
    #h(1fr)
    #text(weight: 400)[#title]
    
    #line(length: 100%, stroke: 0.2pt)
  ]
}

#let prompt(content, lang:"md") = {
  box(
    inset: 15pt,
    width: auto,
    fill: rgb(247, 246, 243, 50%),
  )[#text(content, font: "Cascadia Mono", size: 0.8em)]
}

#let _returns = {
  text("Returns:", font:"Cascadia Mono", weight: 600, size:9pt)
}

#let _params = {
  text("Parameters:", font:"Cascadia Mono", weight: 600, size:9pt)
}

#let _details = {
  text("Details:", font:"Cascadia Mono", weight: 600, size:9pt)
}

#let project(title: "", authors: (), logo: none, body) = {
  set text(9pt, font: "Pretendard")
  set heading(numbering: "1.")
  set page(columns: 1, numbering: "1  /  1", number-align: center, header: head, margin: 5em)
  show outline.entry.where(level: 1): it => {
    v(25pt, weak:true)
    strong(it)
  }
  show heading : it => { it; v(0.5em);}
  
  align(center)[
    #block(text(weight: 800, 1.75em, title))
  ]
  pad(
    top: 0.5em,
    bottom: 0.5em,
    x: 2em,
    grid(
      columns: (1fr,) * calc.min(1, authors.len()),
      gutter: 1em,
      ..authors.map(author => align(center, author)),
    ),
  )
  set par(justify: true)
  outline(title: "목 차", depth: 5, indent: 1em, fill: repeat(text(weight: 700)[.#h(0.5em)]))

  set page(columns: 2, numbering: "1  /  1", number-align: center, header: head)
  set text(8pt, font: "Pretendard")
  body
}