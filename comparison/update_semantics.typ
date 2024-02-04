=== `UPDATE` Semantics <section_update_semantics>

In this subsection, we will look at what files are created when records are updated from a table.

==== Hive

Updates are not supported.

==== Hudi

If `type` is `cow`, a new file slice is created for the file group, containing a copy of the base file of the previous file slice with the updated records.

If `type` is `mor`, a new file slice is created for the file group, containing a binary log file that points to the base file of the previous file slice and indicates which records have been updated.

==== Iceberg

If `write.update.mode` is `copy-on-write`, two new manifests are added: one with `status: 2` (i.e., deleted), which informs about the deletion of the previous data file, and one with `status: 1` (i.e., added), which adds a copy of the previous data file with the updated records.

If `write.update.mode` is `merge-on-read`, a new data file containing the change is added, and a delete file is created for the original file.

==== Delta Lake

Without deletion vectors, the previous data file is removed from the log with a `remove` action, and the new data file, which is a copy of the previous data file with the requested records changed, is added to the log with an `add` operation. The behavior is the same as for deletes. In Trino, this operation is more granular, first removing the changed records from the data file and then writing them as a new data file. Both options are valid, the specification does not provide the correct behavior.

With deletion vectors, the previous data file is removed from the log with a `remove` action, and the same data file is added to the log with an `add` action, but with a deletion vector. The change is added as a separate Parquet file. Trino has read-only support for deletion vectors, no write support.

==== Conclusions

Iceberg and Delta Lake implement MoR-based updates as a delete and insert. Hudi has a dedicated update operation. Deletions are marked in special log files, and additions are regular inserts. We will see the implications of that in @scalability_table_formats. A summary of update semantics is given in @update_semantics_summary.

#figure(
  table(
    columns: 3,
    align: left,
    [*Table Format*], [*Trino*], [*Spark*],
    [Hive], [N/A], [N/A],
    [Hudi (Copy on Write)], [N/A], [Add original data file with records changed],
    [Hudi (Merge on Read)], [N/A], [Add a new (hidden) log file containing information about changed records],
    [Iceberg (Copy on Write)], [N/A], [Add original data with records changed],
    [Iceberg (Merge on Read)], [Add new data file containing a reference to the original data file and the position for each removed record, and a new data file with changed records], [Add new data file containing a reference to the original data file and the position for each removed record, and a new data file with changed records],
    [Delta Lake], [Add original data file with records removed and new data file with updated records], [Add original data file with records changed],
    [Delta Lake (Deletion Vectors)], [r/o], [Add a deletion vector and the changed records as a new data file],
  ),
  caption: [Summary of `UPDATE` semantics],
) <update_semantics_summary>
