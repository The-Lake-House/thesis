=== Specification

The lakehouse architecture envisions that lakehouse tables can be managed by different execution engines such as SQL query engines, machine learning and data science toolkits, and ETL scripts. This is enabled by open specifications with explicitly stated semantics and requirements, so that execution engines can fully implement a lakehouse table format.

In this first subsection, we compare table formats based on the availability of their specification, whether the specification is versioned, whether changes are clearly communicated, and the extent to which the specification is implemented by both Spark and Trino.

#figure(
  table(
    columns: 2,
    [*Table Format*], [*Specification*],
    [Hive], [N/A],
    [Hudi], [https://hudi.apache.org/tech-specs/],
    [Iceberg], [https://iceberg.apache.org/spec/],
    [Delta Lake], [https://github.com/delta-io/delta/blob/master/PROTOCOL.md],
  ),
  caption: [Table format specifications],
)

==== Hive

We have included the Hive table format only for comparison with other table formats. Unlike other table formats, it does not store its metadata on the file system, but in the Hive Metastore (HMS). The table format has no formal specification. Hive itself is used as a reference implementation. The implementation is documented in the project wiki @ApacheHiveWiki.

==== Hudi

At the time of writing, there are seven versions (counting from 0) of the Hudi table format @ApacheHudiGitHuba. The specification @ApacheHudiTechnical only describes version 5. There is no changelog for each version, and the document does not appear to be actively maintained, i.e., changes to the specification are not made as new features are introduced.

The version of a table is noted in the `hoodie.properties` file @ApacheHudiGitHubb, potentially allowing an upgrade or downgrade path for tables.

Spark, as the reference engine, has full support for all features, while Trino supports only bare-bones read-only operations missing features such as the Hudi metadata table.

==== Iceberg

At the time of writing, there are three versions of the Iceberg table format @IcebergTableSpec. Spark and Trino implement version 2. A brief summary of the changes between versions is given at the top of the specification in _Format Versioning_, and there is a section on how version 2 readers can read and write version 1 tables in _Appendix E: Format version changes_.

Spark fully implements both versions, while Trino only has read support for version 1 and only supports row-level version 2 deletes (Merge on Read) and not version 1 type deletes (Copy on Write). Trino also does not support the specified procedures, such as `rewrite_data_files`.

==== Delta Lake

The Delta Lake specification @DeltaTransactionLog has separate reader and writer versions. The requirements for each writer version are listed in _Requirements for Writers_, and the requirements for each reader version are listed in _Requirements for Readers_.

At the time of writing it is not clear how each version has changed. It is possible to specify the minimum versions of the read and write protocols in the `protocol` section of the schema (see _Protocol Evolution_).

==== Conclusions

Ideally, an open table format has a specification that is a) open, b) current, c) complete, and d) versioned with a detailed changelog and clear upgrade and downgrade paths. We found that all of the table formats we tested were missing one or more of these criteria.

An alternative to a specification can be a reference implementation that is optimized for reusability. Delta Lake introduced a preview of a reusable component called Delta Kernel in version 3.0.0 @DeltaLakeRelease300. The Delta Kernel is offered in Java @DeltaioDeltaGitHubd, but a Rust based alternative is planned @DeltaLakeRelease300. Finding a suitable programming language to implement this core component can be challenging, as the JVM and Hadoop dependencies are gradually being replaced by other technologies (see for example the replacement of Java by C++ for better memory management in execution engines @behmPhotonFastQuery2022 or the rise of Jupyter notebooks as clients). In Trino, it has been common practice to delegate to the reference implementation, but work is currently underway to remove Hive dependencies @TrinodbTrinoGitHubf, resulting in the removal of features for certain table formats such as Hudi.

Adding too many features too quickly can be detrimental to the ecosystem because not all execution engines will implement them at the same time. For example, Trino lacks many features. This fact is not emphasized in the documentation.
