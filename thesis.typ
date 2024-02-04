#import "config.typ"
#import "header.typ"
#import "flex-caption.typ" as flex

// PDF metadata
#set document(
  title: config.title,
  author: config.author,
)

#set page(
  paper: "a4",
  flipped: false,
  margin: (
    top: 3cm,
    bottom: 2cm,
    inside: 2.5cm + 1.5cm,
    outside: 2.5cm,
  ),
)

#set text(
  font: "Latin Modern Roman",
  fallback: false,
  size: 12pt,
  lang: "de",
)

// default leading is 0.65em, 1.5 is therefore 0.975
#let spacing1 = 0.65em
#let spacing15 = 0.975em

#set par(
  leading: spacing15,
)

/*
  scale: 1.4
  default above: 1.8
  default below: 0.75
*/
#show heading.where(level: 1): it => {
  set text(size: 14pt, weight: "bold")
  v(1.0em)
  it
}

/*
  scale: 1.2
  default above: 1.44
  default below: 0.75
*/
#show heading.where(level: 2): it => {
  set text(size: 12pt, weight: "bold")
  set block(above: 2.16em, below: 1.125em)
  it
}

/*
  scale: 1
  default above: 1.44
  default below: 0.75
*/
#show heading: it => {
  set text(size: 12pt, weight: "regular")
  set block(above: 2.16em, below: 1.125em)
  it
}

#show footnote.entry: set text(size: 10pt)

// Allow short figure captions for outline
// https://github.com/typst/typst/issues/1295#issuecomment-1853762154
#show outline: it => {
  flex.in-outline.update(true)
  it
  flex.in-outline.update(false)
}

// Do not justify code
#show raw.where(block: true): it => {
  set par(
    justify: false,
    leading: spacing15,
  )
  block(
    width: 100%,
    fill: luma(240),
    inset: 8pt,
    radius: 4pt,
    it,
  )
}

#show figure.where(kind: raw): set block(width: 100%)

#align(right, image("/_img/hfu.svg", width: 36%))
#align(center)[
  #[
    #set text(size: 18pt)
    #set par(leading: 1.2em)
    #config.doctype \
    in \
    #config.program
  ] \
  #[
    #set text(size: 22pt, weight: "bold")
    #set par(leading: 0.9em)
    #config.title
  ] \
  #text(size: 18pt, config.subtitle) \
  \
  #block(width: 65%)[
    #set text(size: 12pt)
    #v(6em)
    #set align(left)
    #grid(
      columns: (0.6fr, 1.4fr),
      gutter: 1.0em,
      "Referent:",
      config.referent,
      "Koreferent:",
      config.koreferent,
      "Vorgelegt am:",
      config.submissiondate,
      "Vorgelegt von:",
      config.author,
      [],
      config.studentid,
      [],
      config.street + " " + config.streetnumber,
      [],
      config.zipcode + " " + config.city,
      [],
      config.emailaddress,
    )
  ]
]

#set par(
  justify: true,
)

#pagebreak()

// Reset page numbering (has to happen before page header is specified)
// set page forces a pagebreak if content is before it, therefore we need to
// set the number to 0 here if we want it to be 1 on the next page
#counter(page).update(0)

#set page(
  header: locate(loc => header.header(loc, pagenumbering: "I")),
  numbering: "I", // Needed for outline
  footer: [],
)

#pagebreak()


= Abstract

#include "abstract/en.typ"

--- \

#include "abstract/de.typ"

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

// Set default line spacing for outlines
#set par(
  leading: spacing1
)

= Table of Contents
#outline(
  title: none,
  depth: 3,
  indent: auto,
)

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

= Table of Figures
#outline(
  title: none,
  target: figure.where(kind: image),
)

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

= Table of Tables
#outline(
  title: none,
  target: figure.where(kind: table),
)

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

= Table of Abbreviations
#table(
  columns: (1fr, 1fr),
  align: left,
  [CoW], [Copy on Write],
  [CBO], [Cost-Based Optimizer],
  [CTAS], [`CREATE TABLE AS SELECT`],
  [ETL], [Extract, Transform, Load],
  [HMS], [Hive Metastore],
  [MoR], [Merge on Read],
  [OLAP], [Online Analytical Processing],
  [OLTP], [Online Transactional Processing],
  [RBO], [Rule-Based Optimizer],
)

#metadata("disable_header") <disable_header>
#pagebreak()

// Reset page numbering (has to happen before page header is specified)
#counter(page).update(0)

#set page(
  header: locate(loc => header.header(loc, pagenumbering: "1")),
  numbering: "1",
  footer: [],
)

#pagebreak()

// Reset line spacing
#set par(
  leading: spacing15,
)

// Automatically number headings
#set heading(numbering: "1.")

// But only for three levels
#show heading.where(level: 4): it => {
  set text(size: 12pt, weight: "regular")
  block(underline(it.body))
}

#show heading.where(level: 5): it => {
  set text(size: 12pt, weight: "regular")
  block(it.body + ":")
}

// Reset language
#set text(lang: "en")

#include "introduction/main.typ"

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#include "background/main.typ"

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#include "comparison/main.typ"

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#include "evaluation/main.typ"

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#include "conclusion/main.typ"

// Reset automatic headings numbering
#set heading(numbering: none)

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#bibliography(
  "references.bib",
  title: "References",
)

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

= Declaration on honest academic work

With this document I, #config.author, declare that I have drafted and created the piece of work in hand myself. I declare that I have only used such aids as are permissible and used no other sources or aids than the ones declared. I furthermore assert that any passages used, be that verbatim or paraphrased, have been cited in accordance with current academic citation rules and such passages have been marked accordingly. Additionally, I declare that I have laid open and stated all and any use of any aids such as AI-based chatbots (e.g. ChatGPT), translation (e.g. Deepl), paraphrasing (e.g. Quillbot) or programming (e.g. Github Copilot) devices and have marked any relevant passages accordingly.

I am aware that the use of machine-generated texts is not a guarantee in regard of the quality of their content or the text as a whole. I assert that I used text-generating AI-tools merely as an aid and that the piece of work in hand is, for the most part, the result of my creative input. I am entirely responsible for the use of any machine-generated passages of text I used.

I also confirm that I have taken note of the document "Satzung der Hochschule Furtwangen (HFU) zur Sicherung guter wissenschaftlicher Praxis" dated October 27, 2022 and that I have followed the statements there.

I am aware that my work may be examined to determine whether any non-permissible aids or plagiarism were used. I also acknowledge that a breach of § 10 or § 11 section 4 and 5 of HFU's study and examination regulations' general part may lead to a grade of 5 or «nicht ausreichend» (not sufficient) for the work in question and / or the exclusion from any further examinations.

\
\
\

#line(length: 50%)
#config.city, #config.submissiondate #config.author

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#counter(heading).update(0)
#set heading(numbering: "A.1")

#include "appendix/supplemental_data.typ"

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#include "appendix/setup.typ"

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#include "appendix/tools.typ"

#metadata("disable_header") <disable_header>
#pagebreak(to: "odd")

#include "appendix/plots.typ"
