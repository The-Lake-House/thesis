#import "/flex-caption.typ" as flex

=== Benchmarks <benchmarks>

In this subsection, we present the dataset used for the benchmark, the benchmarking methods in Spark and Trino, and our test system.


==== Datasets

OLAP systems are widely used in the field of decision support. Many benchmarks have been developed over the years. The most widely used are TPC-H @TPCH, TPC-DS @poessTPCDSTakingDecision2002, and TPC-DI @poessTPCDIFirstIndustry2014, all from the Transaction Processing Performance Council (TPC), which was founded in the late 1980s @shanleyOriginsTPCFirst1998.

All of these benchmarks have a common scale factor that can be used to scale the dataset to any desired size. Scale factor 1 represents about 1 GB of data in the TPC-H dataset and scales linearly from there.

TPC-H and TPC-DS are natively supported by both Presto and Trino via the `tpch` @TrinoDocumentationTPCH and `tpcds` @TrinoDocumentationTPCDS connectors, respectively. TPC-H was chosen for its simplicity.

TPC-H includes both queries and update functions to measure query processing power and query throughput. The data is modeled after that of a wholesale supplier and contains orders from 1992-01-01 through 1998-08-02.

#figure(
  image("/_img/tpc-h.png"),
  caption: flex.flex-caption(
    [The schema of the TPC-H benchmark @TPCH],
    [The schema of the TPC-H benchmark],
  ),
)

In this manuscript, we focus mainly on the `lineitem` table, the largest table with a minimum of 6,000,000 records. Each record in this table represents an item from an order. The tuple `(l_orderkey, l_linenumber)` is a primary key for the table.

In the `tpch` connector, the scale factor can be specified in the schema name in the form of `sf` followed by an integer greater than 0, e.g., `sf1`, `sf2`, `sf3`, and so on. There is also a special scale factor called `tiny` that is not described in the TPC-H specification: where `sf1` represents a dataset of approximately 1 GB, `tiny` represents a dataset that is 100 times smaller.

The TPC-H data can be converted to lakehouse tables using `CREATE TABLE AS SELECT` (CTAS) statements. For example, to create a copy of the `lineitem` table with a scale factor of 1 as an Iceberg table after creating a bucket named `tpch`:

```sql
CREATE SCHEMA IF NOT EXISTS iceberg.tpch_iceberg WITH (location = 's3a://tpch/iceberg');
CREATE TABLE iceberg.tpch_iceberg.lineitem AS SELECT * FROM tpch.sf1.lineitem;
```

In the TPC-H specification each column name is prefixed with a per-table prefix, e.g., the prefix for the `lineitem` table is `l_`. The Trino `tpch` connector omits these prefixes by default, but they can be added by setting `tpch.column-naming=STANDARD` in the catalog configuration file. This way, the standard TPC-H queries do not need to be modified. See @setup_tpch for instructions.

The refresh functions RF1 and RF2 mentioned in the specification are not implemented in Trino. RF1 adds new sales information and RF2 removes old sales information.

*Discussion*: Today, the TPC-H is considered too simple a benchmark @poessTPCDIFirstIndustry2014 that does not represent the real world well @vogelsgesangGetRealHow2018: the data is evenly distributed, has no missing values, no natural clustering or order, and so on @zengEmpiricalEvaluationColumnar2023, making advanced features such as zone maps difficult to evaluate. Zeng et al. present their own datasets with adjustable parameters for many aspects of the data distribution @zengEmpiricalEvaluationColumnar2023 to test the differences between Parquet and ORC.

The simplicity of TPC-H, however, allows the user to quickly generate a variable amount of (potentially very large) data. Each query also covers different "choke points" @bonczTPCHAnalyzedHidden2014. This, along with its ready availability in Trino, was the deciding factor for us.


==== Benchmarking Methods in Trino

We discovered two ways to perform benchmarking in Trino: using a sophisticated version of the UNIX `time` command, or using internal query metadata provided by the `system` connector.

The interactive Trino command-line client is lazy: Trino is pipelined and the client requests the result set page by page. This behavior makes it unsuitable for performance testing. It is better to pass the query with the `--execute` or `--file` command line parameter for non-interactive use. To reduce the overhead of printing the result set, the output can be eliminated, either by setting `--output-format=NULL` or by piping it to `/dev/null`.

*Time*: One way to benchmark Trino-based queries is to use the elapsed time between invoking and exiting the Trino client. This can be tested using the `time` shell built-in, a dedicated `time` implementation such as GNU time, or a dedicated benchmarking tool such as `hyperfine` @peterHyperfine2023.

Although the Trino client tool loads quickly, invoking and exiting it is not free. Measurements with `hyperfine` suggest that the Trino client overhead with an empty query and output piped to `/dev/null` is 641.9 ms ± 4.7 ms.

```bash
$ hyperfine --warmup 5 "$TRINO_HOME/bin/trino --execute='' --output-format=NULL"
Benchmark 1: /home/agrueneberg/trino-server-433/bin/trino --execute='' --output-format=NULL
  Time (mean ± σ):     641.9 ms ±   4.7 ms    [User: 1311.8 ms, System: 67.6 ms]
  Range (min … max):   632.8 ms … 650.9 ms    10 runs
```

This overhead can either be accepted and treated as an intercept. Alternatively, query times can be obtained via the Trino `system` connector.

*`system` Connector*: The `system` connector is a Trino connector that allows introspection of the Trino runtime system and is automatically available via a catalog of the same name @TrinoDocumentationSystem.

By default, the `queries` table of the `runtime` schema in the `system` catalog contains `end` and `started` times of the last 100 queries within the last 15 minutes. The maximum number of queries to be kept in the query history and the minimum age of a query in the history before it expires can be configured with the `query.max-history` and the `query.min-expire-age` configuration properties, respectively.

Each query is listed with its `query_id` and `query` string. However, there is no straightforward way to extract the `query_id` of a query, and the `query` string itself may not be unique (e.g., when trying to measure multiple runs of a particular query). We have found that the most reliable way to extract query times is to vary either the `user` (which defaults to the current system user name) or `source` (which defaults to `trino-cli` in the case of the Trino client) entry of a query with a random string. This can be done by passing either `--user=<user>` or `--source=<source>`. Suitable random strings can be generated on the command line, e.g., using OpenSSL: `openssl rand -hex 4`.

```bash
RANDOM_STRING="$(openssl rand -hex 4)"
$TRINO_HOME/bin/trino --source="$RANDOM_STRING" --file=query.sql --output-format=NULL
$TRINO_HOME/bin/trino --catalog=system --schema=runtime --execute="SELECT TO_MILLISECONDS(\"end\" - started) FROM queries WHERE source = '$RANDOM_STRING';"
```

By using the same random string for a series of queries, even basic benchmark statistics can be calculated:

```bash
RANDOM_STRING="$(openssl rand -hex 4)"
for REP in $(seq 1 "$NUM_REPS"); do
  $TRINO_HOME/bin/trino --source="$RANDOM_STRING" --file=query.sql --output-format=NULL
done
$TRINO_HOME/bin/trino --execute="WITH durations AS (SELECT TO_MILLISECONDS(\"end\" - started) AS duration FROM system.runtime.queries WHERE source = '$RANDOM_ID') SELECT ROUND(VALUE_AT_QUANTILE(TDIGEST_AGG(duration), 0.5), 1) AS median, ROUND(AVG(duration), 1) AS avg, ROUND(STDDEV_SAMP(duration), 1) AS sd FROM durations;"
```

==== Benchmarking Methods in Spark

Compared to Trino, Spark's benchmarking options are limited: the overhead of starting Spark is much higher than that of the Trino client and the variability depends on the types of plugin packages that are fetched and bootstrapped.

Measuring query runtime using timers before and after the query is issued using the `spark.sql()` function in the `spark-shell` has a similar problem due to lazy plugin initialization.

This leaves the use of using event log files. Event logging must be enabled for each session with `--conf spark.eventLog.enabled=true`. By default, logs are written to `/tmp/spark-events`, but this can be changed using the `spark.eventLog.dir` configuration parameter, which must be an absolute path.

```bash
$SPARK_HOME/bin/spark-sql --conf spark.eventLog.enabled=true --conf spark.eventLog.dir=$HOME/spark-events -f query.sql
```

Log files are stored in JSON Lines @JSONLines format, meaning that each event is represented as one JSON document per line. Relevant event types (as specified in the `Event` field) are `org.apache.spark.sql.execution.ui.SparkListenerSQLExecutionStart` and `org.apache.spark.sql.execution.ui.SparkListenerSQLExecutionEnd`. These events occur when the execution of an SQL statement begins or ends, respectively. The UNIX timestamp of the event is recorded in the `time` field of the event. We consider the difference between the end and the beginning of the execution to be the query runtime.

There is one log file for each Spark session, so the log can contain more than one query event. Automatic extraction becomes difficult when there are many query events. We limited ourselves to creating a separate Spark session for each query by passing the query string with `spark-sql -e`, but even then there are at least two query events when `--database` is used to set the schema because `--database` is converted internally to a `USE` statement. The log file is written after the Spark session has been terminated.

Each query has a unique `executionId` that can be used to find corresponding event pairs. Once the log file is written, the query runtime can be calculated by subtracting the `time` field of the `SparkListenerSQLExecutionStart` object from the `time` field of the `SparkListenerSQLExecutionEnd` object. If the schema was specified with `--database`, we used an `executionId` of `1`, otherwise `0`.

We used the following shell script combining jq @Jq and awk to extract the runtimes, assuming that `--database` was used:

```bash
paste <(jq --slurp 'map(select(.Event == "org.apache.spark.sql.execution.ui.SparkListenerSQLExecutionStart" and .executionId == 1) | .time) | .[]' LOG_DIR/*) <(jq --slurp 'map(select(.Event == "org.apache.spark.sql.execution.ui.SparkListenerSQLExecutionEnd" and .executionId == 1) | .time) | .[]' LOG_DIR/*) | awk '{print $2 - $1}'
```

The script can be used on an entire directory of log files because log files contain a timestamp and are therefore ordered.

Some queries start other jobs, possibly asynchronous in the background (e.g., Delta Lake performs snapshot expiration at checkpoint creation). These timings are difficult to capture automatically.


==== Test System

The test system was set up as a distributed system with three nodes, as shown in @test_system_architecture: a worker node running Trino or Spark, a storage node running MinIO, and a metadata node running the Hive Metastore. Each node is a virtual machine managed by VMWare, with disk storage provided by an HDD-based Storage-Attached Network (SAN). The network has a minimum bandwidth of 1 Gbps. The hardware is described in @test_system_hardware_spark and the software versions are described in @test_system_software.

We have not increased the number of Spark worker nodes because support for table formats must be added via plugins, and some plugins are incompatible with each other (see @section_execution_engines).

#figure(
  image("/_img/benchmark_system.svg"),
  caption: [Architecture of the test system],
) <test_system_architecture>

#figure(
  table(
    columns: 4,
    [*Node*], [*CPU*], [*RAM*], [*Disk*],
    [Worker], [8 CPUs], [32 GB], [15 GB],
    [MinIO], [4 CPUs], [16 GB], [115 GB],
    [Hive Metastore], [2 CPUs], [2 GB], [15 GB],
  ),
  caption: [Hardware of the test system],
) <test_system_hardware_spark>

The disk setup for MinIO is not optimal: MinIO "strongly recommends" the use of direct-attached XFS-formatted disks @MinIODocumentationDeploy, but our system is fully virtualized. We observed rare hangups, especially during object listings, using both ext4 and XFS filesystems, and often had to adjust the default timeouts where possible (e.g., in @scalability_object_storage). We do not believe that the hangups are related to the virtualized environment, as we have seen them in non-virtualized environments as well.

#figure(
  table(
    columns: 2,
    [*Software*], [*Version*],
    [Operating System], [Debian Bookworm],
    [Apache Hadoop], [3.3.2],
    [Apache Hive], [3.1.3],
    [Trino], [433],
    [Apache Spark], [3.4.2],
    [Apache Hudi], [0.14],
    [Apache Iceberg], [1.4.3],
    [Delta Lake], [2.4.0],
    [MinIO], [2023-12-20T01-00-02Z],
  ),
  caption: [Software versions of the test system],
) <test_system_software>

The software has been set up as described in @setup.
