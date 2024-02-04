=== Table Maintenance <table_maintenance>

Each change to a lakehouse table creates a new snapshot with new data files and metadata files, potentially increasing query runtimes, storage space, etc.

We distinguish three types of table maintenance procedures: those that reduce the number of data files, those that reduce the number of metadata files, and those that reduce the number of snapshots.


==== File Merging <file_merging>

File merging aims to reduce the number of data files by merging smaller files together.

In Spark, each table format has a different approach to merging files.

In Hudi, merging files is called clustering @HudiClustering. Clustering is an automatic process that is disabled by default, but can be enabled by setting `hoodie.clustering.inline`. By default, data files are automatically clustered after 4 commits, which can be configured with the `hoodie.clustering.inline.max.commits` parameter. The process is synchronous, so writes will take longer than usual. Almost every aspect of clustering is customizable, it can even be configured to run asynchronously as part of other table services. However, and importantly, there is no manual equivalent.

Iceberg provides a manual procedure called `rewrite_data_files` for merging files:

```sql
CALL system.rewrite_data_files('schema.table');
```

`rewrite_data_files` allows sorting during merging (see _rewrite_data_files_ in @IcebergProcedures).

Delta Lake for Spark has an `OPTIMIZE` command that allows manual merging of small files:

```sql
OPTIMIZE schema.table;
```

`OPTIMIZE` also allows for sorting during merging.

Trino has a universal mechanism for all table formats: the manual `optimize` procedure merges the data files of the current snapshot smaller than a certain threshold into fewer, evenly-sized ones.

```sql
ALTER TABLE catalog.schema.database EXECUTE optimize(file_size_threshold => '1GB');
```

For Hive, this only works if the `hive.non_transactional_optimize_enabled` session property is set. Since Hive is not transactional, it will read, write, and delete the original files. For Delta Lake, `delta.enable-non-concurrent-writes` must be set when using S3 as the storage system.

The `optimize` procedure will only combine smaller files, but will not split files that are too large. For this, the file size caps introduced in @file_sizes should be used.

The `optimize` procedure does not currently allow for reordering of data.


==== Compaction <compaction>

Compaction is a special case of file merging, aimed at either merging multiple log files into a single log file, or merging log files with a corresponding base file. Of course, this mechanism is only supported in MoR tables.

Hudi supports compaction similar to file merging: synchronous compaction can be set to trigger automatically after a certain number of writes. This can be enabled by setting `hoodie.compact.inline`, and the number of writes can be configured with the `hoodie.compact.inline.max.delta.commits` property, which interestingly defaults to 5 instead of 4. Like clustering, compaction can be tweaked in many ways, but again cannot be done manually.

The `rewrite_position_delete_files` procedure in Iceberg can be used to compact delete files @IcebergProcedures. As with `rewrite_data_files`, there is no automatic equivalent.

```sql
CALL system.rewrite_position_delete_files('schema.table');
```

`rewrite_position_delete_files` compacts not only successive deletes, but also deletes that occur as part of updates (see @section_update_semantics).

Delta Lake does not require compaction because, according to our observations, deletion vectors are already compacted on each write. We could not find proper documentation of this behavior, except that the term `deletionVector` is singular in the `add` action.


==== Snapshot Elimination <cleanup>

Both file merging and compaction create new snapshots in addition to all the other snapshots created by changes. Preserving too many previous versions of a table adds storage costs and snapshot reconstruction overhead (e.g., log replay in Delta Lake without checkpointing, slower file listings in Hudi, and exploding metadata in Iceberg).

*Hudi*: Hudi has a cleaner service that is enabled by default @HudiCleaning. By default, it only retains the last 10 commits. This can be configured with the `hoodie.cleaner.commits.retained` property. Like other table services, the cleanup is done synchronously on write.

Many aspects of cleaning can be configured. It even supports different cleaning strategies: in addition to the one based on the number of requests, there are ones based on time and the number of file versions.

*Iceberg*: Iceberg has two different cleanup procedures: one for metadata and one for data files. Deleting metadata does not delete the data files. Data files are not deleted unless the associated metadata has been deleted.

In Spark, Iceberg has a way to automatically remove previous versions: if `write.metadata.delete-after-commit.enabled` is set in the table properties, only versions up to `write.metadata.previous-versions-max` are kept, and older metadata files are deleted after new versions are created @IcebergMaintenance.

Trino only supports manual cleanup using the `expire_snapshots` procedure. This procedure has different parameters than the one in Spark:

```sql
ALTER TABLE catalog.schema.table
EXECUTE expire_snapshots(retention_threshold => '0s');
```

This will remove all snapshots that are older than `retention_threshold`. As a safety mechanism, `retention_threshold` must be greater than or equal to the catalog property `iceberg.expire_snapshots.min-retention`, which also defaults to `7d`.

To delete orphaned data files, use the `remove_orphan_files` procedure:

```sql
ALTER TABLE catalog.schema.table
EXECUTE remove_orphan_files(retention_threshold => '0s');
```

It works similarly to `expire_snapshots`, with `iceberg.remove_orphan_files.min-retention` controlling the minimum retention span of data files.

`expire_snapshots` and `remove_orphan_files` are also supported in Spark, but with a different syntax, e.g., `CALL catalog.system.expire_snapshots('db.table');` expires all snapshots older than five days by default @IcebergProcedures.

*Delta Lake*: Spark has a `VACUUM` command @DeltaLakeDataRetention. It deletes obsolete data files that are older than `delta.deletedFileRetentionDuration` (which defaults to 7 days), but keeps log files intact. Obsolete log files older than `delta.logRetentionDuration` (which is 30 days by default) are automatically removed when a new checkpoint is created.

In Trino, the cleanup procedure is also called `vacuum`.

```sql
CALL delta.system.vacuum('schema', 'table', '0s');
```

This will remove both metadata and data files in the transaction log that are older than the threshold passed as the third argument. As a safety mechanism, this threshold must be greater than or equal to the `delta.vacuum.min-retention` catalog property, which is `7d` by default.

==== Conclusions

Each table format provides a way to perform file merging, compaction, and snapshot elimination. Ideally, both manual and automatic procedures are provided so that both on-demand and periodic compaction can be performed. Automatic procedures are a good up-sell to commercial lakehouse platforms such as Dremio for Iceberg and Databricks for Delta Lake. Snapshot elimination usually has safeguards to prevent accidental deletion of recent data, for usability and transaction safety reasons @DeltaLakeDocumentationb.

Hudi has a unified system called table services, which includes clustering, compaction, and cleaning. All services can be disabled at once by unsetting the `hoodie.table.services.enabled` property.
