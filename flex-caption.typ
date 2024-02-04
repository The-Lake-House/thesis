#let in-outline = state("in-outline", false)

#let flex-caption(long, short) = locate(loc => 
  if in-outline.at(loc) { short } else { long }
)
