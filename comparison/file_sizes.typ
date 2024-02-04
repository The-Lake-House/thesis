=== File Sizes <file_sizes>

Storage files should be right-sized, i.e., not too small and not too large.

Having too many small files is a problem known as the small files problem. The term is commonly used to describe memory limitations of NameNodes in HDFS, but the small files problem also manifests itself in other areas, such as low disk utilization, network congestion, processing overhead (e.g., Parquet footer parsing), over/under-utilization of resources, data fetching overhead and so forth @aggarwalSmallFilesProblem2022. For column-oriented storage formats, another disadvantage is poorer compression performance. Finally, in table formats, especially in Iceberg and Delta Lake, each data file typically corresponds to a manifest or Delta file, respectively. This adds additional metadata that needs to be traversed and stored. In object stores, these problems persist and are even exacerbated by higher latencies and higher file listing overheads (see @request_types).

Avoiding small data files is difficult because execution engines are massively parallel and process tasks split by split on different nodes, making coordination to produce a single file at the end expensive. Instead, each worker produces its own file, or sometimes even each split produces its own file. In @tpch_benchmark, we discuss techniques such as limiting the number of writers per task to address this problem.

Files that are too large will also degrade performance (see @parquet_size_determination). Therefore, execution engines typically place an upper limit on file size.

Hudi creates comparatively small Parquet files: the maximum file size is 125,829,120 bytes, which is enough space for a single row group with the typical row group size of 128 MB (`write.parquet.block.size` defaults to 120). The maximum file size can be adjusted with `hoodie.parquet.max.file.size` @HudiAllConfigurations in Spark.

Iceberg writes the largest files: the maximum file size is 536,870,912 bytes (512 MiB) by default and can be controlled with `write.target-file-size-bytes` in Spark @IcebergWriteProperties.

Delta Lake does not limit data files by default. Spark has a system-wide configuration property called `spark.sql.files.maxRecordsPerFile` that can be used to set the maximum number of records per file @DeltaioDeltaGitHubf. Note that this mechanism is not based on file size like the others.

In Trino, the maximum file size of a data file can be set in a connector independent way using the connector specific `target-max-file-size` property (`hive.target_max_file_size`, `delta.target_max_file_size`, `iceberg.target_max_file_size`).

In addition to right-sized files, there should be neither too few nor too many data files. Too few files can limit parallelism in cases where split generation is not optimal (see @split_size_determination), and too many files can increase file listing overhead (see @request_types).
