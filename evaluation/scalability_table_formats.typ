#import "/flex-caption.typ" as flex

== Scalability of Table Formats <scalability_table_formats>

To measure the overhead attributable to the table formats, rather than to the overhead attributable to data transfers, we designed several load tests using a minimal dataset:

- Many Inserts
- Many Deletes
- Many Updates

These experiments test how each table format handles a consecutive number of change operations, such as inserts, deletes, and updates.

The data is that of a key-value store containing key-value pairs: the column definition of the `store` table is `(key INT, value INT)`. In addition to minimizing data transfers due to the small size of the data, it also minimizes the risk of running out of disk space due to successive operations. A minimal dataset allows us to ignore split generation, since each split is guaranteed to contain all records in the data file. Because we control the key space, we also avoid additional I/O requests for data generation, e.g., we do not need to generate or select a random sample for insertion or deletion.

These analyses were performed in Spark instead of Trino because Trino does not support all of the features of interest in table formats. Where applicable (see @table_types), we split each table format into its corresponding Merge-on-Read (MoR) or Copy-on-Write (CoW) variant. As in the previous section, we aim for comparability by adjusting defaults and disabling potential mitigations that are enabled by default.

For all Hudi variants, we disabled the Hudi metadata table (see @metadata_concepts), table services (especially the automatic cleaner, see @table_maintenance), and the embedded timeline server (see @hudi_file_caching).

For all Iceberg variants, `commit.manifest-merge.enabled` was unset in the table properties (see @iceberg_rewrite_position_delete_files). In addition, `--conf spark.sql.catalog.spark_catalog.cache-enabled=false` (see @caching) was passed to Spark as an argument.

For all Delta Lake variants, the table property `delta.checkpointInterval` has been set to `2000000000`. This is an arbitrarily high number to disable checkpointing (see @delta_checkpointing).

Each analysis was run N=125 times. The number of repetitions is quite small due to the large runtime overhead of Spark. In Trino, it is possible to run many more repetitions, but not all possible variants can be tested. However, we think that the number of repetitions is large enough to pick up trends and eliminate automatic table management procedures that are triggered after a certain number of writes (e.g., the `commit.manifest-merge.enabled` option).

A table scan is performed after each operation. For both the change operation and the table scan, the runtime and number of S3 requests are measured, as well as the number and sizes of objects in the object store. In addition, system metrics are captured with sar.

All experiments were run in `spark-sql`. Storage options were passed with `OPTIONS (key = value)`, table properties with `TBLPROPERTIES (key = value)`, and Spark configuration parameters with `--conf key=value`. For each analysis, `--conf spark.sql.parquet.compression.codec=gzip` was set.

For tables that start with a fixed amount of data, the tables are created first, and then data is added. This results in at least two transactions in transactional table formats. We have not found a good way to use a `CREATE TABLE AS SELECT` (CTAS) statement with generated data.

We chose to include both CoW and MoR variants in this analysis even though we expect them to perform very differently on most metrics because CoW requires copying existing data and MoR does not. However, the cost of copying data is close to zero with a minimal dataset like this, so to account for the differences between CoW and MoR, we ran an alternative version of the analysis that includes 1,000,000 initial values in the table to penalize CoW. The results of this analysis can be found in the appendix, @section_scalability_table_formats_initial. We cross-reference these results when we find surprising differences between CoW and MoR.

The following sections present each analysis, its results, and key takeways.

=== Many Inserts

In the _Many Inserts_ scenario, we test how table formats handle many consecutive inserts into a table.

==== Protocol

Starting with an empty table, a single key-value pair is inserted one at a time. Each time, the key is incremented by 1, starting from 1. The value is 0.

```
for (i = 1; i <= N; i++) {
  INSERT INTO store VALUES (i, 0);
}
```

==== Tested Variants

- Hive
  - Storage options
    - `'fileFormat' = 'parquet'`
- Hudi (CoW)
  - Table properties
    - `'hoodie.spark.sql.insert.into.operation' = 'insert'`
- Hudi (MoR)
  - Table properties
    - `'hoodie.spark.sql.insert.into.operation' = 'bulk_insert'`
- Iceberg (MoR)
- Delta Lake (Without Deletion Vectors)

Both Hudi (CoW) and Hudi (MoR) use the default `'type' = 'cow'` internally, which made no difference for this analysis. We consider `bulk_insert` to be MoR and `insert` to be CoW, as described in @section_insert_semantics.

==== Results

#figure(
  image("/_img/scalability_table_formats/many_inserts.svg"),
  caption: flex.flex-caption(
    [Results of the _Many Inserts_ analysis],
    [Results of the Many Inserts analysis],
  )
) <many_inserts_fig>

The runtimes of inserts, shown in @many_inserts_fig a), are as expected. The MoR-based variants run in almost constant time (with Hudi (MoR) and Delta Lake having slight slopes), and Hudi (CoW) has an upward slope proportional to table size compared to @many_inserts_1000000_fig a). Hudi's performance is generally worse than its competitors.

Inversely, Hudi (CoW) has a constant runtime for table scans, while the MoR-based variants have an upward slope (see @many_inserts_fig b)). Considering that Delta Lake has to replay its log (and therefore has a much higher number of requests), it is surprising that its performance is better than that of Iceberg. Hudi starts off much better than its competitors, but the slope of Hudi (MoR) quickly overtakes them.

The number of S3 requests for inserts in @many_inserts_fig c) shows similar patterns to the runtime, with the exception of Delta Lake, which does not have a constant number of S3 requests as expected. This is surprising at first, but the writer has to determine the current version and therefore needs to do a log replay. The current version could be embedded in the Hive Metastore (HMS), similar to Iceberg, but it is not, probably because of checkpointing. The initial bump for Hudi is due to the fact that there are no commit files after the table is created. Surprisingly, Iceberg uses fewer requests than Hive, even though it has to write additional metadata files. Hudi has a higher baseline, probably due to its implementation of upserts and optimistic concurrency control.

Based on the read path analysis in @read_path, we can determine how many files are involved in a table scan. 100 insertions correspond to 100 files in Hive, 402 files in Hudi, 400 files in Iceberg, and 200 files in Delta Lake. As we can see in @many_inserts_fig d), the number of requests is generally much higher than the number of files, and this has several reasons: a) the use of file listings, b) the use of stat requests to check if files exist and to get their file sizes, and c) the use of range requests to avoid downloading the entire data file. The use of parallel computing exacerbates this problem because each thread has to request the same information over and over again. Iceberg performs the best in this category, while Delta Lake performs the worst, which is surprising given its overall much smaller number of files; it appears that the log replay is done twice.

The total bucket size shown in @many_inserts_fig e) also has some surprises. The most notable is that Hudi has outlier characteristics: both Hudi (Cow) and Hudi (MoR) take up so much space that the curves for Hive and Delta Lake appear constant where they should be linear (see @du_wo_hudi_fig for a version of the plot without Hudi). This behavior is not only due to the extra metadata columns added to each data file (see @supported_storage_formats), but primarily due to the embedded Bloom filter, which we could not find a way to disable. While the Bloom filter appears huge with a minimal dataset, it has a constant size, and its impact diminishes as more data is added to the table as shown in @many_inserts_1000000_fig e). More worrisome is the nonlinear component in Iceberg, as it must incorporate all previous changes in each snapshot. We will address this in @iceberg_rewrite_position_delete_files.

#figure(
  image("/_img/scalability_table_formats/du_wo_hudi.svg"),
  caption: [Total size of bucket without Hudi (CoW)],
) <du_wo_hudi_fig>

Unlike in @many_inserts_fig d), the values in f) are exactly as expected. For Hive, there is one data file per insert. For Hudi, there is one request, one inflight, one commit, and one data file per insert, plus two metadata files (`hoodie.properties` and `.hoodie_partition_metadata`). For Iceberg, there is one data file, one manifest, one manifest list, and one snapshot per insert. Finally, for Delta Lake, there is one Delta file and one data file per insert.


=== Many Deletes

In the _Many Deletes_ scenario, we test how table formats handle many consecutive deletes from a table.

==== Protocol

Starting with an empty table, which is then filled with N+1 key-value pairs, where the keys are a sequence from 1 to N+1 and the values are 0, the key-value pair with the lowest key is removed one by one.

N+1 is chosen so that at least one key-value pair remains at the end. Some table formats are optimized for when data files are empty.

```
for (i = 1; i <= N; i++) {
  DELETE FROM store WHERE key = i;
}
```

==== Tested Variants

- Hudi (CoW)
- Hudi (MoR)
  - Table properties
    - `'type' = 'mor'`
- Iceberg (CoW)
- Iceberg (MoR)
  - Table properties
    - `'write.delete.mode' = 'merge-on-read'`
    - `'write.update.mode' = 'merge-on-read'`
    - `'write.merge.mode' = 'merge-on-read'`
- Delta Lake (Without Deletion Vectors)
- Delta Lake (With Deletion Vectors)
  - Table properties
    - `'delta.enableDeletionVectors' = true`

Hive is not listed because deletes are not supported.

==== Results

#figure(
  image("/_img/scalability_table_formats/many_deletes.svg"),
  caption: flex.flex-caption(
    [Results of the _Many Deletes_ analysis],
    [Results of the Many Deletes analysis],
  )
) <many_deletes_fig>

@many_deletes_fig a) shows that both Hudi variants are worst in class for query runtime for deletes. Surprisingly, Hudi (MoR) performs even worse than Hudi (CoW) with or without initial data (see @many_deletes_1000000_fig a)). The Iceberg variants start in a similar position, but then diverge: Iceberg (CoW) is constant, while Iceberg (MoR) is linear. This is unexpected: it seems that Iceberg (MoR) has to check all previous delete files to read a new one. Delta Lake has almost constant performance, just as in the _Many Inserts_ scenario, with and without deletion vectors. In fact, it is almost impossible to tell the difference between the two.

As with the query runtime for table scans in @many_deletes_fig b), Hudi (CoW) and Delta Lake behave just like in the _Many Inserts_ scenario. Hudi (MoR) has a much higher baseline, in fact the highest. Iceberg (CoW) is constant as expected, but Iceberg (MoR) has the steepest slope. Delta Lake again shows no difference between the variant with and without deletion vectors. Interestingly, both Hudi (MoR) and Iceberg (MoR) seem to flatten out after 100 operations.

The number of S3 requests for deletes in @many_deletes_fig c) shows that, overall, more requests are needed for a delete than for an insert, with the exception of Hudi (CoW), which has the same update cost as the _Many Inserts_ scenario. There is only one variant with constant update performance: surprisingly, it is the CoW-based Iceberg variant. Iceberg (MoR) has the steepest slope, even though it has the lowest intercept. It is followed by Delta Lake, and then, not nearly as steep, both Hudi variants. Hudi (MoR) surprisingly performs worse than Hudi (CoW).

Iceberg worryingly dominates the number of S3 requests for table scans (see @many_deletes_fig d)). The performance of Hudi (MoR) and Delta Lake is significantly better than their performance in the _Many Inserts_ scenario. Iceberg (CoW) and Hudi (CoW) are constant; Hudi (CoW) seems to use the same number of requests as before. Deletion vectors in Delta Lake seem to add a small overhead.

The total bucket size shown in @many_deletes_fig e) is similar to the previous experiment. The main difference is that the base files in Hudi (MoR) have been replaced by log files, and these do not contain the Bloom filter, so the size requirements are in an acceptable range. However, in @du_wo_hudi_fig we can see that the curve for Hudi (MoR) is slightly non-linear, although not nearly as sharp as for Iceberg. This is because each `.deltacommit` file tracks an array containing the path of each log file, so the overhead is negligible in practice. The delete files in Iceberg are larger than the actual Parquet files (1540 bytes vs. 790 bytes), hence the small gap.

Finally, the number of objects in the bucket also shows almost identical patterns. Iceberg (CoW) has two metadata files for each deletion: one that deletes the previous data file, one that adds the new one. This can be seen in @many_updates_fig f).


=== Many Updates

In the _Many Updates_ scenario, we test how table formats handle many consecutive updates in a table.

==== Protocol

Starting with an empty table that is then populated with a single key-value pair `(1, 0)`, the value of the key-value pair is incremented each round.

```
for (i = 1; i <= N; i++) {
  UPDATE store SET value = i [WHERE key = 1];
}
```

==== Tested Variants

- Hudi (CoW)
- Hudi (MoR)
  - Table properties
    - `'type' = 'mor'`
- Iceberg (CoW)
- Iceberg (MoR)
  - Table properties
    - `'write.delete.mode' = 'merge-on-read'`
    - `'write.update.mode' = 'merge-on-read'`
    - `'write.merge.mode' = 'merge-on-read'`
- Delta Lake (Without Deletion Vectors)

Hive is not listed because updates are not supported.

==== Results

#figure(
  image("/_img/scalability_table_formats/many_updates.svg"),
  caption: flex.flex-caption(
    [Results of the _Many Updates_ analysis],
    [Results of the Many Updates analysis],
  )
) <many_updates_fig>

The query runtimes are almost identical to the _Many Deletes_ scenario for both updates (@many_updates_fig a)) and table scans (@many_updates_fig b)). Iceberg (MoR) is less steep than in the previous scenario, which is surprising because it not only uses far more requests in both categories than its competitors (see @many_updates_fig c) and @many_updates_fig d)), but also the most files (@many_updates_fig f)). It also results in a larger bucket size than Iceberg (CoW) compared to the previous analysis (@many_updates_fig e)).


=== Conclusions

In this test, the comparison between MoR and CoW variants proves to be difficult. The minimal dataset is so small that copying it does not show much impact on any of the metrics. In fact, we were surprised to find that some CoW-based variants, such as Iceberg (CoW) and to some extent Delta Lake (Without Deletion Vectors) are the overall top performers on the change-related metrics.

#figure(
  table(
    columns: 3,
    [*Table Type*], [*Operation*], [*Tested Variants*],
    [MoR], [Insert], [Hive, Hudi (MoR), Iceberg (MoR), Delta Lake (Without Deletion Vectors)],
    [MoR], [Delete], [Hudi (MoR), Iceberg (MoR), Delta Lake (With Deletion Vectors)],
    [MoR], [Update], [Hudi (MoR), Iceberg (MoR)],
    [CoW], [Insert], [Hudi (CoW)],
    [CoW], [Delete], [Hudi (CoW), Iceberg (CoW), Delta Lake (Without Deletion Vectors)],
    [CoW], [Update], [Hudi (CoW), Iceberg (CoW), Delta Lake (Without Deletion Vectors)],
  ),
  caption: [Tested variants broken up by table type and operation],
) <many_ops_tested_variants_tbl>

Here we will focus on MoR-based variants (see @many_ops_tested_variants_tbl), namely Hive, Hudi (MoR), Iceberg (MoR), and Delta Lake (Without Deletion Vectors) for inserts, Hudi (MoR), Iceberg (MoR), and Delta Lake (With Deletion Vectors) for deletes, and finally Hudi (MoR) and Iceberg (MoR) for updates.

For inserts, Hive represents the baseline. It is assumed that support for Hive is the most mature, since Hive was invented at Facebook (now Meta) @thusooHivePetabyteScale2010 and then replaced first by Spark SQL and later by Presto @sunPrestoDecadeSQL2023. In Hive, only the data files are stored in object storage, so the storage size and number of objects are the smallest. Data files are stored with a low constant number of requests, and retrieved with a higher than expected but fixed number of requests. Query runtime is not best in class, but comparable to Iceberg (MoR) and Delta Lake.

Hudi (MoR) handles inserts poorly and has the highest query runtime for both updates and table scans. The number of requests is the lowest, but when proper mitigations are used, the other formats can be better (see @iceberg_rewrite_position_delete_files and @delta_checkpointing). Like Iceberg, Hudi has a slight nonlinearity in storage requirements, but only for MoR. For inserts, the embedded Bloom filters, which cannot be disabled (see @indexing), are a distraction, but their effect diminishes for larger datasets, as shown in @many_inserts_1000000_fig e).

For inserts, Iceberg (MoR) performs slightly better than the baseline for query runtime and number of requests, but its nonlinear storage requirements are hard to ignore. In fact, this nonlinearity caused problems when running this analysis with a larger number of repetitions (>5000) in Trino. We would not recommend using this variant for fast query ingestion. For deletes and updates, this variant performs worst in almost every category. By rewriting delete files as shown in @iceberg_rewrite_position_delete_files, we can solve some of these problems for deletes.

While Delta Lake has superior and predictable performance on all other metrics, it is penalized on the number of requests metric because it must perform log replay to determine the current version of the table. In @delta_checkpointing, we see that checkpointing can effectively reduce the number of S3 requests to the baseline.

The best way to optimize MoR tables is to compact them, and if possible, clean up snapshots (see @table_maintenance).

What we did not consider: different delete and update types. Except for Hudi and its record key-based deletes, we focused on positional deletes, although some formats also support equality-based deletes.
