=== `DELETE` Semantics <section_delete_semantics>

In this subsection, we will look at what files are created when records are deleted from a table.

==== Hive

Deletes are not supported.

==== Hudi

If `type` is `cow`, a new file slice is created for the file group, containing a copy of the base file of the previous file slice with the requested records removed.

If `type` is `mor`, a new file slice is created for the file group, containing a binary log file that references the base file if the previous file slice, and indicates which records were deleted by record key (see @indexing).

These log files are in a custom binary container format that embeds data in the Parquet, Avro, or HFile format (see _Log File Format_ in @ApacheHudiTechnical). They contain the record key and partition path of each record to be deleted.

Log files of other table formats typically list the positions or predicate values of the rows to be removed. Using record keys for deletions should have a negative impact on performance, because lookups have to be performed, especially for large Parquet files, unless a record index is used (see @indexing).

Log files are not automatically compacted as in Delta Lake, i.e., they are pure MoR.

==== Iceberg

If `write.delete.mode` is `copy-on-write`, two new manifest files are added: one with `status: 2` (i.e., deleted), which informs about the deletion of the previous data file, and one with `status: 1` (i.e., added), which adds a copy of the previous data file minus the removed records. The first is for information only and is not processed further.

If `write.delete.mode` is `merge-on-read`, a manifest with `content: 1` (i.e., positional delete) is added. The manifest points to a Parquet file ending in `-deletes.parquet`, which contains the `file_path` and the 0-indexed `pos` of the records to be removed, a so-called delete file. This manifest is added with `status: 1` (i.e., added) to the manifest list. In Trino, the delete file has no special name: it looks like a regular data file.

Delete files and data files have the same file format by default, but this can be changed with the `write.delete.format.default` table property in Spark.

==== Delta Lake

Without deletion vectors, the previous data file is removed from the log with a `remove` action, and the new data file, which is a copy of the previous data file with the requested records removed, is added to the log with the `add` action. The `remove` action must include the `path` and `dataChange` fields.

With deletion vectors, the previous data file is removed from the log with a `remove` action, and the same data file is added to the log with an `add` action, but with an object in `deletionVector` that specifies `storageType`, `pathOrInlineDv`, `offset`, `sizeInBytes`, and `cardinality`. In our case, `storageType` is `u` (i.e., stored in a file) and `pathOrInlineDv` is a base85-encoded UUID pointing to a file named `deletion_vector_UUID.bin` in the base directory. On the command line, a sample string can be formatted as follows:

```bash
$ UUID=$(printf 'rrZLoRQ!rXYhTHFL>u$$' | basenc -d --z85 | basenc --base16)
$ echo ${UUID:0:8}-${UUID:8:4}-${UUID:12:4}-${UUID:16:4}-${UUID:20:12} | tr '[:upper:]' '[:lower:]'
5505caf2-a6d6-491f-bb54-85e894f53791
```

Deletion vector files are in yet another binary format (see _Deletion Vectors_ in @DeltaTransactionLog). There is currently no command-line tool for interpreting them. The UUID handling seems more complicated than necessary. We could not figure out how to add an inline deletion vector.

Currently, Trino supports reading of deletion vectors, but not writing @TrinodbTrinoGitHube.

Deletion vectors are combined in subsequent delete operations, i.e., they exhibit CoW behavior. This means that each data file can have at most one deletion vector. Having a log-based mechanism based on CoW is unique, but it avoids the problem of having to read too many small files, and since log files are small, even copying a large number of them should not have a large impact on storage requirements. `cardinality` is the sum of the records removed.

==== Conclusions

All table formats, except Hive, which does not support deletes at all, provide both CoW and MoR semantics. A summary is provided in @delete_semantics_summary. Again, Trino does not support all of these operations.

#figure(
  table(
    columns: 3,
    align: left,
    [*Table Format*], [*Trino*], [*Spark*],
    [Hive], [N/A], [N/A],
    [Hudi (Copy on Write)], [N/A], [Add original data file with records removed],
    [Hudi (Merge on Read)], [N/A], [Add a new (hidden) log file containing information about removed records],
    [Iceberg (Copy on Write)], [N/A], [Add original data with records removed],
    [Iceberg (Merge on Read)], [Add new data file containing a reference to the original data file and the position for each removed record], [Add new data file containing a reference to the original data file and the position for each removed record],
    [Delta Lake], [Add original data file with records removed], [Add original data file with records removed],
    [Delta Lake (Deletion Vectors)], [r/o], [Add a deletion vector],
  ),
  caption: [Summary of `DELETE` semantics],
) <delete_semantics_summary>

Delta Lake automatically compacts consecutive deletions automatically into a single deletion vector. Iceberg does not.
