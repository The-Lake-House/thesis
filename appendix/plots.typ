#import "/flex-caption.typ" as flex

= Plots

Here are additional plots that did not make it into the main manuscript.

== Scalability of Table Formats with Initial Records <section_scalability_table_formats_initial>

#figure(
  image("/_img/scalability_table_formats/many_inserts_1000000.svg"),
  caption: flex.flex-caption(
    [Results of the _Many Inserts_ analysis with 1,000,000 initial records],
    [Many Inserts with 1,000,000 initial records],
  ),
) <many_inserts_1000000_fig>

#figure(
  image("/_img/scalability_table_formats/many_deletes_1000000.svg"),
  caption: flex.flex-caption(
    [Results of the _Many Deletes_ analysis with 1,000,000 initial records],
    [Many Deletes with 1,000,000 initial records],
  ),
) <many_deletes_1000000_fig>

#figure(
  image("/_img/scalability_table_formats/many_updates_1000000.svg"),
  caption: flex.flex-caption(
    [Results of the _Many Updates analysis_ with 1,000,000 initial records],
    [Many Updates with 1,000,000 initial records],
  ),
) <many_updates_1000000_fig>
