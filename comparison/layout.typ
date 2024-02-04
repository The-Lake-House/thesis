=== Data Layout Optimizations <data_layout>

Data layout optimizations change the way records are assigned to data files so that, given a certain predicate, data files can be eliminated from further processing. Common techniques include partitioning, bucketing, and sorting.

In partitioning, records with a certain attribute value are grouped into a shared directory. All table formats support this type of partitioning. Partitions can be nested.

In bucketing, the attribute value of a record is hashed and assigned to a fixed number of buckets accordingly. This is supported only by Hive and Iceberg.

We gloss over partitioning and bucketing because these optimizations are useful when using the same predicate over and over, but may penalize queries that use different predicates.

Sorting is another technique that can be applied to individual data files as well as entire tables. In Hive, only buckets can be sorted. In Hudi, data can be sorted during bulk inserts or during clustering (see @table_maintenance). In Iceberg, the sort order of each table can be specified in the table metadata, but it is unclear when this information is used. Sort order can be specified during `rewrite_data_files` (see @table_maintenance). Delta Lake only allows sorting during `OPTIMIZE` (see @table_maintenance).
