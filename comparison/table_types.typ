=== Table Types <table_types>

All transactional table formats have converged on having read-optimized or write-optimized versions for common table operations such as `DELETE`s and `UPDATE`s. The read-optimized versions are based on Copy-on-Write (CoW) and the write-optimized versions are based on Merge-on-Read (MoR).

In CoW, a copy of an existing data file is made and the changes are applied. The modified copy is then saved as a new file. When reading, only the updated file needs to be read. Slower writes are traded for faster reads.

In MoR, the data file remains the same and is augmented with additional information describing the update. On read, the data file plus all the extra information must be read. Faster writes are traded for slower reads.

As a rule of thumb, CoW should be used in scenarios with more reads than writes, while MoR benefits those with more writes than reads. In the context of big data, however, CoW may not be practical unless previous versions are quickly discarded, since each change duplicates the data.

Inserts play a special role here, since tables naturally consist of more than one file. This is for several reasons, but primarily because large files limit parallelism.

==== Hive

Hive only supports inserts, and these are implemented by appending data files, i.e., with MoR characteristics.

==== Hudi

There are two types of tables in Hudi: Copy-on-Write (CoW) tables and Merge-on-Read (MoR) tables. The type of a table can be specified using the `type` table property: either `cow` or `mor`. CoW tables are created by default.

```sql
CREATE TABLE name
TBLPROPERTIES (type = 'mor');
```

The type of a table is tracked in the `hoodie.table.type` property of the `.hoodie/hoodie.properties` file (see next subsection). Once the table is created, the table type cannot be changed.

==== Iceberg

Iceberg allows setting the table type for each operation: the table properties `write.delete.mode` and `write.update.mode` can be set to either `copy-on-write` or `merge-on-read`. The default operation type is `copy-on-write`. Iceberg does not support CoW-based inserts.

```sql
CREATE TABLE name
TBLPROPERTIES (write.delete.mode = 'merge-on-read', write.update.mode = 'merge-on-read');
```

==== Delta Lake

In Delta Lake, all operations are CoW-based by default. Deletions can be tracked in a MoR-based manner by enabling deletion vectors:

```sql
CREATE TABLE name
TBLPROPERTIES (delta.enableDeletionVectors = true);
```

Deletion vectors are a recent addition to Delta Lake: they were introduced in Delta Lake 2.4.0 @DeltaLakeRelease240.

In Delta Lake 3.0, deletion vectors have been extended to updates @DeltaLakeRelease300, but this version is only compatible with Spark 3.5.0 @DeltaLakeDocumentationa and our target release of Spark is 3.4.0 due to Hudi.

==== Conclusions

Hudi is the only format that supports CoW-based inserts. Iceberg is the only format that allows CoW and MoR to be set for individual operations (e.g., MoR-based updates, but CoW-based deletes). @supported_table_formats summarizes the table type support in commonly used table formats.

#figure(
  table(
    columns: 4,
    [*Table Format*], [*Inserts*], [*Deletes*], [*Updates*],
    [Hive], [MoR], [N/A], [N/A],
    [Hudi], [MoR, CoW], [MoR, CoW], [MoR, CoW],
    [Iceberg], [MoR], [MoR, CoW], [MoR, CoW],
    [Delta Lake], [MoR], [MoR, CoW], [CoW],
  ),
  caption: [Table types broken down by operation],
) <supported_table_formats>

Not all table types are supported by all execution engines. For example, Trino only supports MoR-based deletes and CoW-based updates in Iceberg @TrinoDocumentationIceberg, and currently cannot write deletion vectors in Delta Lake @TrinodbTrinoGitHube.
