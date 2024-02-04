= Conclusion

In this final chapter, we conclude this thesis by looking at the state of table formats, object stores, and execution engines.


== Table Formats

Table formats allow multiple storage files to be logically treated as a single entity, a table. This table can be used not only in SQL-based query engines, but also in more general-purpose execution engines such as Spark through the DataFrame API. The key innovation of table formats is mutability: structured changes can be made to files in a data lake.

We compared several table formats, such as Apache Hudi, Apache Iceberg, and Delta Lake. Despite our best efforts, this comparison was not always fair. As discussed in @mitigations, all table formats have workarounds for their most pressing problems, and most mitigations are enabled by default. Disabling them for our experiments allowed us to look under the covers to understand the nature of these mitigations and assess whether they work as intended.

Conventional wisdom suggests using Copy-on-Write (CoW) for read-heavy tasks and Merge-on-Read (MoR) for write-heavy tasks. In practice, it is not possible to avoid copying altogether. At some point, compaction is unavoidable, especially in a scenario where inserts, deletes, and updates are mixed, and in Iceberg and Delta Lake, which only track deletions in log files. Many advanced optimizations, such as sorting, require a complete rewrite of the data.

Having both files that are too large and files that are too small is problematic. A tradeoff has to be made. In practice, the number of files is much larger because we cheated here and limited write parallelism to produce fewer files. We think the ideal storage file size depends on both the use case and the table format, but more research is needed. We have only used a seemingly arbitrary heuristic set by Trino to base our conclusions on, but this value is not set in stone.

=== Hudi

Hudi has the most complex design of all the table formats tested. Without reading the specification, it was difficult to deduce the existence of file groups and file slices from observing the system. Hudi is also the most feature-rich, in particular it is the only one with record keys. This adds storage overhead to storage files because they must be recorded, violating the property of other table formats that raw storage files do not change. We think that the record keys are responsible for the higher query runtimes than other formats.

Hudi allows almost every aspect of the format to be configured, but this complexity leads to outdated documentation and conflicting configuration parameters. Despite our best efforts to develop a good understanding of the table format, we may have overlooked a configuration parameter that solves all of our problems, such as the file index not working as intended.

However, Hudi is the only format that allows inserts with CoW semantics and true MoR updates without creating tons of new file groups. This solves a major problem with other table formats: that each update creates new data files, which in turn must track log files unless compacted.

Hudi does not have much metadata to work with. The Hudi metadata table is an attempt to improve this, but there does not seem to be much commitment to it at the moment. Trino doesn't support it, file skipping and all other indexes are disabled by default, and there is talk of introducing more centralized services in Hudi 1.0 @HudiRFC69.

=== Iceberg

Snapshots in Iceberg can be processed in $O(1)$, but metadata files grow so large over time that Delta Lake's sequential approach performs better on almost every metric. Iceberg also has a suboptimal way of handling updates: first delete, then insert, resulting in more data files than necessary. This can be addressed with `rewrite_positional_delete_files`, but all updates must still be properly compacted. If not, each data file may have its records changed again, resulting in even more metadata files.

A metadata structure where each snapshot is independent of the others facilitates auditability. In fact, Iceberg supports branches and tags that can be retained forever. Iceberg also doesn't clean up by default.


=== Delta Lake

Delta Lake is conceptually the simplest format: log files are easy to traverse and performance is consistent and predictable. However, despite its simplicity, newer features such as deletion vectors feel unnecessarily complicated. Current versions of the format add deletion vectors to update and merge operations.

Occasional checkpointing is required to reduce the cost of log replay. This makes Delta Lake unsuitable for cases where time travel and auditability are required: checkpointing triggers log cleanup, and by default Delta Lake only retains 30 days of logs.


== Object Storage

Our analysis of object storage was limited to MinIO. MinIO is fairly easy to set up, but has strange performance characteristics, indefinite hangs, and long timeouts. More research is needed to determine if this is representative of S3.

We also found that comparing object stores is not straightforward: even those that support the S3 API may have different consistency guarantees. In fact, even S3 itself started out as eventually consistent and is not strongly consistent.

The execution engines we tested do not seem to be optimized for object stores. In general, there are too many `HeadObject` requests followed by ranged `GetObject` requests where single ranged `GetObject` requests would have sufficed. These requests add to the bill or can trigger throttling, etc. This behavior is likely due to the reliance on abstraction layers to bundle different distributed file systems under a common set of methods (such as the Hadoop Filesystem API).

The use of `ListObjectsV2` is unanimously discouraged, yet table formats still rely on it. Its poor performance can be mitigated by parallel requests and caching. More problematically, file listings may not be up to date due to consistency issues, which is one of the reasons why Iceberg and Delta Lake embed file names of data files and log files in snapshot metadata in the first place.

S3 lacks certain operations, such as atomic renaming, that make it difficult to port table formats to object stores. For example, writes to Amazon S3 and S3-compatible storage must be explicitly enabled in Delta Lake due to write collisions with other engines.


== Execution Engines

Initially, we did all our experiments in Trino until we discovered that many features were not available, e.g., write support in Hudi and CoW operations in Iceberg. This is to be expected since the code in Trino is not the reference implementation, but it also goes the other way: for example, extended statistics in Iceberg that are specified in the standard can currently only be generated in Trino. At some point, support for the Hudi metadata table was removed from Trino, a regression with potentially serious performance implications (since the file index and table statistics are stored in it) that was not even mentioned in the changelog.

We like how easy it is to work with multiple table formats in Trino. This may change in Spark once all table format plugins support the Spark 3 catalog API. In general, there is less configuration overhead in Trino, and common performance techniques such as the cost-based optimizer (CBO) are already enabled. There are also more instances of in-memory caching throughout the Trino codebase.

There are a few features that are implemented differently between Spark and Trino, such as updates (see @section_update_semantics). We would like to see more precise definitions of these operations in the table format specifications.

Our experiments have shown that more work could be done on the coordinator to avoid overloading the storage system with too many parallel requests, e.g., adding the split boundaries of each file to the metadata (see @split_size_determination).


== Future Directions

Table formats are still under heavy development. During the preparation of this thesis, Hudi introduced the record-level index and autogenerated keys in version 0.14 @HudiRelease14, and Delta Lake introduced deletion vectors for both updates and merges, and the Universal Format (UniForm) that generates Iceberg metadata when writing to a Delta table @DeltaLakeDocumentationc in versions 3.0.0 @DeltaLakeRelease300 and 3.1.0.

Currently, execution engines typically require a catalog to find tables. In the future, the catalog may need to take on more responsibilities to implement features such as governance and multi-table transactions. For example, a centralized transaction manager is mentioned in the draft design documents for multi-table transactions in both Hudi @HudiRFC73 and Iceberg @MultiTableTransactionsIceberg. However, introducing a centralized infrastructure raises scalability and reliability concerns and precludes certain use cases (e.g., processing on HPC clusters that limit cluster-wide services). Also, mediating requests through governance engines may limit direct access to data files in the data lake, making machine learning and data science use cases impossible. In summary, care must be taken not to push the needle too far in the direction of cloud-based data warehousing, or the benefits of data lakes may be lost.

There is one component missing from our analyses of lakehouse components: a platform. A platform could integrate the disparate components of a lakehouse into a cohesive system and provide additional features such as automated table maintenance, indexing guarantees, and caching. Commercial lakehouse platform offerings include Databricks @Databricks, Dremio @Dremio, and IBM watsonx.data @IBMWatsonxData.

A lakehouse system is greater than the sum of its parts. It offers the best of both data warehouses and data lakes. It will be exciting to watch the ecosystem mature.
