#import "/flex-caption.typ" as flex

== Object Store Request Types <request_types>

We broke down the number of requests from @scalability_table_formats by request type to determine the percentage of `ListObjectsV2` for both table scans and update operations.

In addition, we performed another analysis similar to the load tests in @scalability_table_formats, but measuring the overhead of creating a new partition for each insert depending on the table type. This scenario, called _Many Inserts (Parititioned)_, was designed to show the overhead of creating additional partitions.

We discovered that the number of `ListObjectsV2` calls in both read and write paths is constant and does not change with the number and type of operations. It changes only with the number of partitions in the read path, and only in Hive and Hudi (in both CoW and MoR).

Most of the other requests are due to reading and writing data files.

=== Read Path

On the read path, we find only `GetObject`, `HeadObject`, and `ListObjectsV2` calls.

#figure(
  image("/_img/request_types/many_inserts_scan.svg"),
  caption: flex.flex-caption(
    [Request types for a table scan in the _Many Inserts_ scenario],
    [Request types: Many Inserts table scan],
  ),
)

In the _Many Inserts_ scenario, Iceberg (MoR) is the only format that can perform full table scans without `ListObjectsV2`. While barely visible, both Delta Lake (Without Deletion Vectors) and Hive use 4 requests, and Hudi (CoW) and Hudi (MoR) use 9.

#figure(
  image("/_img/request_types/many_inserts_partitioned_scan.svg"),
  caption: flex.flex-caption(
    [Request types for a table scan in the _Many Inserts (Partitioned)_ scenario],
    [Request types: Many Inserts (Partitioned) table scan],
  ),
)

In the _Many Inserts (Partitioned)_ scenario, Iceberg (MoR) is the only format that can perform full table scans without `ListObjectsV2`. Delta Lake (Without Deletion Vectors) uses 4 after 125 inserts, Hive 125, and Hudi (CoW) and Hudi (MoR) 137.

=== Write Path

On the write path, we find `GetObject`, `HeadObject`, `ListObjectsV2`, `PutObject`, `DeleteMultipleObjects`, `DeleteObject`, and `CopyObject` calls.

#figure(
  image("/_img/request_types/many_inserts_op.svg"),
  caption: flex.flex-caption(
    [Request types for an insert in the _Many Inserts_ scenario],
    [Request types: Many Inserts change operation],
  ),
)

#figure(
  image("/_img/request_types/many_inserts_partitioned_op.svg"),
  caption: flex.flex-caption(
    [Request types for an insert into a new partition in the _Many Inserts (Partitioned)_ scenario],
    [Request types: Many Inserts (Partitioned) change operation],
  ),
)

Even Iceberg (MoR) uses 4 `ListObjectsV2` calls for each insertion. Delta Lake (Without Deletion Vectors) uses 9, Hive 67, Hudi (CoW) 75, and Hudi (MoR) 76. When a a new partition is created, both Hudi (CoW) and Hudi (MoR) use 87 calls.


=== Conclusions

We found that some formats play better with object storage than others. Iceberg avoids `ListObjectsV2` altogether when reading data, while Hive and Hudi depend on it for listing files in partitions. Spark uses `ListObjectsV2` to list the contents of the `_delta_log` directory, while Trino uses multiple sequential requests. On the write path, all table formats issue `ListObjectsV2` requests, but Hive and Hudi in particular make extensive use of these calls.

Prefixing (via the `prefix` URL parameter) allows specific tables and partitions to be targeted, limiting but not eliminating the damage. Partition skipping is also a way to avoid unnecessary file listings.

When used with object stores, Hudi, which is designed for stream ingestion, may perform poorly for frequent change operations unless some workarounds are used, such as S3 caching or possibly the Hudi file index (currently unsupported in Trino @HUDI7020FixConnector).

We can further distinguish between formats that are optimized for object stores and those that are not by looking at the request types on the write path. `DeleteObject`, `DeleteMultipleObjects`, and `CopyObject` appear to be related to temporary file handling, such as creating a temporary file, filling it, copying it to the base directory when the transaction commits, and deleting the temporary data as done in Hive and Hudi @ApacheHudiGitHubg.

Spark makes many `HeadObject` requests to determine if an object is present in the bucket, possibly to get the size of the object for more efficient `Range` requests. Iceberg and Delta Lake should be able to work without `HeadObject` altogether because the file sizes are already embedded in the metadata. The amount of `HeadObject` requests may be due to optimizations for HDFS-based filesystem APIs.

Another peculiarity of Spark is the use of `ListObjectsV2` in combination with the `max-keys=2` URL parameter to check if a directory exists in a bucket. In Delta Lake, this is used to check for the existence of the `_delta_log` directory. MinIO has an optimization for these "garbage requests" @MinioMinioGitHub.
