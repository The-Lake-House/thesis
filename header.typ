/**
 * Show header unless there <disable_header> is found on previous page and the
 * current page is even.
 *
 * Note: These calculations are based on _real_ page numbers.
 *
 */
#let isshowheader(loc) = {
  let curpage = loc.page()
  let iscurpageeven = calc.even(curpage)
  not (query(<disable_header>, loc).filter(el => el.location().page() == curpage - 1) != () and iscurpageeven)
}

#let header(loc, pagenumbering: "1") = {
  // Assumption: If the real page number (loc.page()) is odd, the customized
  // page number is also odd
  let curpage = counter(page).at(loc).first()
  let iscurpageeven = calc.even(curpage)
  if isshowheader(loc) {
    set text(size: 12pt, weight: "bold")
    let curheading
    // The header is processed before the headings on the page, so check if a new
    // chapter starts on the current page and if not, use the title of the
    // previous chapter
    let nextheadings = query(selector(heading.where(level: 1)).after(loc), loc)
    let prevheadings = query(selector(heading.where(level: 1)).before(loc), loc)
    if nextheadings != () {
      let nextheadingpage = counter(page).at(nextheadings.first().location()).first()
      if curpage == nextheadingpage {
        curheading = nextheadings.first()
      } else {
        if prevheadings != () {
          curheading = prevheadings.last()
        }
      }
    } else {
      // Handle last chapter
      if prevheadings != () {
        curheading = prevheadings.last()
      }
    }
    let curheadingstr
    // Add heading numbering to heading (main text and appendix only)
    if curheading.numbering == "1." or curheading.numbering == "A.1" {
      let curheadingcntr = numbering(curheading.numbering, counter(heading).at(curheading.location()).first())
      curheadingstr = str(curheadingcntr) + " " + curheading.body
    } else {
      curheadingstr = curheading.body
    }
    // On odd pages, the page number must be on the outside, on even pages,
    // the page number must be on the inside
    let curpagestr = numbering(pagenumbering, curpage)
    if iscurpageeven {
      curpagestr + h(1fr) + curheadingstr
    } else {
      curheadingstr + h(1fr) + curpagestr
    }
    move(
      dx: -0.5%,
      dy: -0.8em,
      line(length: 101%, stroke: 0.5pt)
    )
  }
}
