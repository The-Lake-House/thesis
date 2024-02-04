=== Caching <caching>

There are caching opportunities at almost every step of the way: there is metastore caching, data file caching, table metadata caching, table statistics caching, and so on. These caches can be per-thread, per-node, per-cluster, per-datacenter, or even global, and they can serve their data from either SSD, HDD, or memory.

Surprisingly, the specifications for Hudi, Iceberg, and Delta Lake do not mention caching at all. Searching through the documentation, Hudi mentions the file index and the timeline server as vague caching mechanisms, which we are experimenting with in @mitigations. Iceberg has a configuration property called `spark.sql.catalog.catalog-name.cache-enabled` that allows catalog caching, configurable by `spark.sql.catalog.catalog-name.cache.expiration-interval-ms` which defaults to 30 seconds.

Spark can cache the contents of a table or the output of a query using the `CACHE` command @SparkDocumentationCACHE, but this is not recommended by Delta Lake (see _Spark caching_ in @DeltaLakeDocumentation). There is also a `spark.sql.metadataCacheTTLSeconds` configuration property which is disabled by default.

Trino has more native caching support than Spark. Trino supports

- metastore caching in Hive (e.g., `hive.metastore-cache.cache-partitions`, `hive.metastore-cache-ttl`, `hive.metastore-cache-maximum-size`, `hive.metastore-stats-cache-ttl`, `hive.metastore-refresh-interval`, `hive.metastore-refresh-max-threads`),

- metastore caching based on `CachingHiveMetastore` in Hudi and Delta Lake (`*.per-transaction-metastore-cache-maximum-size`),

- S3 caching in Hive, mainly directory listing cache (`hive.file-status-cache-tables`, `hive.file-status-cache-expire-time`, `hive.file-status-cache.max-retained-size`, `hive.per-transaction-file-status-cache.max-retained-size`),

- storage caching in HDFS (`hive.cache.enabled`, `hive.cache.location`, `hive.cache.ttl`, `hive.cache.disk-usage-percentage`),

- Delta file caching (the JSON files in `_delta_log`) in Delta Lake using `io.trino.cache.EvictableCacheBuilder` (`delta.metadata.cache-ttl`, `delta.metadata.cache-size`),

- active data file cache using `io.trino.cache.EvictableCacheBuilder` in Delta Lake (`delta.metadata.live-files.cache-ttl`, `delta.metadata.live-files.cache-size`).

Caching in object stores is controversial: MinIO does not do it because "caching is rarely a benefit. It adds complexity and hard to debug scenarios and reduces scalability and availability. Instead we just make the server fast." @MinioMinioGitHuba.

Caching can be particularly effective in reducing the high latencies of cloud object stores by caching the data closer to the processing nodes. Tools like Alluxio @Alluxio specialize in this.

In summary, there seems to be a reluctance to adopt caching on a large scale, even though neither data files nor metadata files change, and that the elimination of snapshots is a clear trigger for cache invalidation.
