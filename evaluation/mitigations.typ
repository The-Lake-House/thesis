#import "/flex-caption.typ" as flex

== Selected Mitigations <mitigations>

In @scalability_table_formats, we have identified some idiosyncratic issues in the MoR-based versions of each table format. Hudi is slower than other table formats and relies on too many file listings, Iceberg has nonlinear metadata growth, and the cost of log replay in Delta Lake is too high. In the following sections, we present selected mitigations to address these issues.


=== Hudi: File Index & Timeline Server <hudi_file_caching>

Hudi has at least two mechanisms for reducing the overhead of file listings: the timeline server and the `files` index within the Hudi metadata table.

The timeline server is an embedded server within the Spark driver, accessible by Spark executors, designed to reduce file listings by building a file-system view directly from metadata added by Hudi as part of the commit @HudiRFC03. The `files` index within the Hudi metadata table is also intended to improve the file listing performance by avoiding direct file system calls @HudiRFC15. The `files` index contains information about all files in all partitions, including size and whether they have been deleted.

Our expectations when using both were reduced query times and reduced number of S3 requests, especially `ListObjectsV2` calls, as we expected file groups and current file slices to be pre-determined. However, as seen in @figure_hudi_hmt_num_reqs and @figure_hudi_hmt_times, while we noticed some management overhead when updating the Hudi metadata table, we did not observe any change in either metric when performing table scans in the _Many Inserts_ scenario (see @scalability_table_formats). Whether this is due to configuration errors or the nature of our experiment on a single node with a single partition is unclear.

#figure(
  image("/_img/mitigations/hudi_hmt/num_reqs.svg"),
  caption: flex.flex-caption(
    [The effect of the Hudi metadata table (HMT) and timeline server on the number of S3 requests for inserts],
    [Num. requests for inserts with HMT and timeline server],
  ),
) <figure_hudi_hmt_num_reqs>

#figure(
  image("/_img/mitigations/hudi_hmt/times.svg"),
  caption: flex.flex-caption(
    [The effect of the Hudi metadata table (HMT) and timeline server on the query runtimes for inserts],
    [Query runtimes for inserts with HMT and timeline server],
  ),
) <figure_hudi_hmt_times>

The core vision for Hudi 1.0 is a third metadata management option in the form of a metadata server similar to the Hive Metastore (HMS) @HudiRFC69. An alternative to the HMS is needed because it is incompatible with some of Hudi's features @ApacheHudiGitHub.


=== Iceberg: `rewrite_position_delete_files` <iceberg_rewrite_position_delete_files>

We found that Iceberg has nonlinear metadata growth and worst in class performance for number of S3 requests in the _Many Deletes_ and _Many Updates_ scenarios for both deletes and table scans (see @scalability_table_formats). This is because deletions are tracked in MoR fashion, unlike Delta Lake, which tracks its deletion vectors in CoW fashion by automatically compacting them.

This can be handled in Iceberg with the `rewrite_position_delete_files` procedure, which combines all positional deletes into a single file. This also works when deletes have been mixed with updates.

#figure(
  image("/_img/mitigations/iceberg_rewrite_position_delete_files/num_reqs.svg"),
  caption: flex.flex-caption(
    [The effect of `rewrite_position_delete_files` on the number of S3 requests for deletes],
    [Num. requests for deletes with `rewrite_position_delete_files`],
  ),
) <iceberg_rewrite_position_delete_files_num_reqs_fig>

#figure(
  image("/_img/mitigations/iceberg_rewrite_position_delete_files/times.svg"),
  caption: flex.flex-caption(
    [The effect of `rewrite_position_delete_files` on query runtimes for deletes],
    [Query runtime for deletes with `rewrite_position_delete_files`],
  ),
) <iceberg_rewrite_position_delete_files_times_fig>

@iceberg_rewrite_position_delete_files_num_reqs_fig shows the number of S3 requests used for a delete operation after running `rewrite_position_delete_files` described in @scalability_table_formats after every write, after every 10 writes, after every 25 writes, and after every 50 writes.

The results are dramatic: the number of requests after compaction in this scenario effectively goes to zero. In addition, as shown in @iceberg_rewrite_position_delete_files_times_fig, there is virtually no update runtime overhead; in fact, it becomes constant because there is no need to traverse log files.

One oddity of `rewrite_position_delete_files` is that old manifests are not purged from the manifest list in the same snapshot. Only the following snapshot will remove these manifests from the manifest list.

There is also an automatic mechanism called manifest merge, which is triggered after every 100 writes by default. It is controlled by the `commit.manifest-merge.enabled` table property. This only results in a slight reduction in the number of requests without any significant runtime gain.

Unfortunately, `rewrite_position_delete_files` is a manual process. Some query engines, such as Dremio Cloud, provide automatic table cleanup features @hudsonDremioBlogAnnouncing2023.

Given the low cost of rewriting delete files, we recommend doing this often if consecutive deletes are performed frequently.

This can also help counteract the compounding effect on space requirements of not eliminating snapshots frequently because the individual snapshots are kept small.

=== Delta Lake: Checkpointing <delta_checkpointing>

The number of S3 requests required for a table scan and for a change operation in a Delta Lake table can be reduced using checkpointing. Checkpointing is an automatic process that is triggered when a certain number of writes have occurred. Automatic checkpointing can be controlled using the `delta.checkpointInterval` table property. It defaults to 10 @DeltaioDeltaGitHub, which is currently undocumented @DeltaioDeltaGitHuba. There is currently no official way to manually create checkpoints; this feature is considered internal @DeltaioDeltaGitHubb.

We varied the _Many Inserts_ scenario in @scalability_table_formats by setting different values for `delta.checkpointInterval`: in addition to disabling it by setting an arbitrarily high value, checkpoints are automatically created after every write, every 10 writes, every 25 writes, and every 50 writes. The results are shown in @delta_checkpointing_num_reqs_fig and @delta_checkpointing_times_fig.

#figure(
  image("/_img/mitigations/delta_checkpointing/num_reqs.svg"),
  caption: flex.flex-caption(
    [The effect of checkpointing on the number of S3 requests for inserts],
    [Num. requests for inserts with checkpointing],
  ),
) <delta_checkpointing_num_reqs_fig>

Checkpointing eliminates the overhead of log replay, and is therefore an improvement for writes, but only a marginal improvement for reads, since the data files are kept as-is and not merged. The latter would have to be done manually using the table maintenance procedures described in @table_maintenance.

#figure(
  image("/_img/mitigations/delta_checkpointing/times.svg"),
  caption: flex.flex-caption(
    [The effect of checkpointing on query runtimes for inserts],
    [Query runtime for inserts with checkpointing],
  ),
) <delta_checkpointing_times_fig>

When checkpointing for the first time, there is a slight jump in query runtime, probably due to the way checkpoints are handled, which should amortize after \~200 writes.

Checkpointing creates additional metadata files: `_delta_log/_last_checkpoint` and `_delta_log/VERSION.checkpoint.parquet` for each checkpoint.
