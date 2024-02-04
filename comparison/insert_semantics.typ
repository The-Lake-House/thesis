=== `INSERT` Semantics <section_insert_semantics>

In this subsection, we will look at what files are created when records are inserted into a table. In general, there are two types of inserts: MoR-based and CoW-based. If a new additional data file is added, it is a MoR-based insert, and if a new data file replaces the previous data file, we consider it a CoW-based insert.

==== Hive

A new data file is added. All metadata is stored in the Hive Metastore (HMS).

==== Hudi

Hudi supports both MoR-based and CoW-based inserts. This can be controlled by the `hoodie.spark.sql.insert.into.operation` table property, regardless of the table type (`type`). We consider `hoodie.spark.sql.insert.into.operation = 'insert'` to be CoW inserts and `hoodie.spark.sql.insert.into.operation = 'bulk_insert'` to be MoR inserts. The default is `insert`.

`insert` is consistent with other CoW operations: the current file slice of a file group is merged with the new records and a new file slice is written.

`bulk_insert` is consistent with Hive: a new file group is created. This is not consistent with the MoR semantics in other Hudi operations, which are usually expressed as a new file slice for the file group.

The value of `hoodie.spark.sql.insert.into.operation` is not stored in `.hoodie/hoodie.properties`, but in the table metadata in the Hive Metastore (HMS). This is probably because `hoodie.spark.sql.insert.into.operation` is considered an operation-specific property, not a table-specific property.

Support for `insert` has limitations when used with MoR tables: once file slices contain log files, inserts are rolled over to a new file group. One might expect the file slice to be compacted and then modified, but this is not currently the case.

When the first file group is inserted, Hudi creates a hidden file called `.hoodie_partition_metadata` in the base directory. This file contains partition information: the last `commitTime` and the `partitionDepth`. Each partition within a subdirectory contains a `.hoodie_partition_metadata` and the `partitionDepth` corresponds to how deep the partitions are nested: `0` means the partition is in the base directory (i.e., the table is not partitioned), `1` means there is one partitioning column, `2` means there are two, and so on.

==== Iceberg

A new data file and its manifest are created. The manifest is added to a copy of the manifest list from the previous snapshot and written. The table metadata is copied and the manifest list is added as a new snapshot. The `metadata_location` property of the table object in the HMS is updated.

==== Delta Lake

A new data file is created and added to a new Delta file with the `add` action. An `add` action must contain the following fields: `path`, `partitionValues`, `size`, `modificationTime`, and `dataChange`. It can optionally include `stats`, `deletionVector`, and others.

==== Conclusions

Inserting data into a table results in a new data file being added in all but one case, namely Hudi in `insert` mode. A summary is shown in @table_insert_semantics_summary. Not all of these are supported in Trino.

#figure(
  table(
    columns: 3,
    align: left,
    [*Table Format*], [*Trino*], [*Spark*],
    [Hive], [Add new data file], [Add new data file],
    [Hudi (`insert`)], [N/A], [Merge original and new data file],
    [Hudi (`bulk_insert`)], [N/A], [Add new data file],
    [Iceberg (Copy on Write)], [N/A], [Add new data file],
    [Iceberg (Merge on Read)], [Add new data file], [Add new data file],
    [Delta Lake], [Add new data file], [Add new data file],
    [Delta Lake (Deletion Vectors)], [N/A], [Add new data file],
  ),
  caption: [Summary of `INSERT` semantics],
) <table_insert_semantics_summary>

MoR-based insertions should be fast in all formats due to their low overhead. We test this hypothesis in @scalability_table_formats.
