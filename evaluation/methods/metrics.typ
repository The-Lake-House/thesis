=== Metrics <metrics>

Throughout this chapter, we use several metrics to compare lakehouse table formats:

1. Query runtime
2. Number of S3 requests
3. Type of S3 requests
4. Size of files in object store
5. Number of files in object store
6. Number of splits
7. Query plan estimates
8. Resource monitoring

The query runtime and resource monitoring metrics are the only metrics that are variable (i.e., they can fluctuate for all kinds of reasons), while the others are fixed.

In this report, the metrics are presented either as text or as graphs. All plots were generated using the ggplot2 @wickhamGgplot22016 and data.table @barrettDataTableExtension2023 packages for R @rcoreteamLanguageEnvironmentStatistical2023.

==== Query runtime

This metric measures the runtime of a query in milliseconds (ms). In @benchmarks, we discuss several ways to benchmark both Trino and Spark queries without much overhead.

==== Number of S3 requests

The number of S3 requests is a measure of both performance and cost. Requests to object stores have a higher latency than requests to a POSIX file system due to their use of TCP/IP, so the less the better. S3 also charges for both the number of requests and the amount of data transferred.

The number of requests was measured using MinIO tracing, as described in @tracing. This metric depends on the implementation of the scan planner and the Parquet reader among other things and can therefore be difficult to interpret. For example, some scan planners are multithreaded and do not share information between threads, so the same information is requested multiple times.

==== Type of S3 requests

Each type of S3 request has distinct performance characteristics, e.g., `ListObjectsV2` scales poorly as we will see in @scalability_object_storage. This metric allows us to examine the distribution of different types of S3 requests.

The request types were extracted from the MinIO trace log file as follows:

```bash
sed -n -e "s/.*s3.\(\w\+\).*/\1/p" TRACE_FILE | sort | uniq -c
```

==== Size of files in object stores

Another cost factor of object stores is the amount of data stored over time. We measured the total size of each bucket using `mcli du` or `s3cmd du`.

Unlike the `du` command on UNIX-like systems, `mcli du` and `s3cmd du` measure the actual file size, not the size in blocks that the file occupies. This can be an important distinction because most metadata files are quite small, smaller than the typical block size of 4 KiB.

For reference, a minimal Parquet file written with `pyarrow` (based on C++) @PythonApacheArrow, consisting of a single integer key-value pair using GZIP compression, is 484 bytes without statistics and schema, 747 bytes with statistics but without schema, 751 bytes with schema but without statistics, and 1015 bytes with both.

==== Number of files in object stores

While there is virtually no limit to the number of objects in a bucket, a larger number of files comes with a higher listing cost (see @scalability_object_storage). We measured the number of files using `mcli du` or `s3cmd du`.

We originally measured the number of files from the output of `mcli ls` or `s3cmd ls`, but MinIO (version 2023.11.20) occasionally hung on file listings.

==== Number of splits

The number of completed splits per task, similar to the query runtimes in @benchmarks, can be retrieved via the `system` connector in Trino. This metric can be helpful when trying to understand split generation in different table formats (e.g., in @tpch_benchmark).

```bash
RANDOM_STRING="$(openssl rand -hex 4)"
$TRINO_HOME/bin/trino --source="$RANDOM_STRING" --file=query.sql --output-format=NULL
$TRINO_HOME/bin/trino --catalog=system --schema=runtime --execute="SELECT completed_splits FROM queries AS q INNER JOIN tasks AS t ON q.query_id = t.query_id WHERE source = '$RANDOM_STRING' ORDER BY task_id DESC;"
```

==== Query plan estimates

For some queries (such as @tpch_benchmark) it was helpful to compare query plan estimates between the different table formats. See @query_plan for more details.

==== Resource monitoring

During the benchmark, the `sar` utility from the `sysstat` package @Sysstat was used to monitor all available system resources, including CPU usage, memory usage, disk I/O, and network I/O. A sample was taken every second at the lowest possible resolution.

```bash
sar -o benchmark.sar -A 1
```

The samples were visually examined using a fork of the original kSar tool @sitnikovVlsiKsar2024. Plots were generated from `sadf -d` output due to its better timestamp handling.
