=== Tracing <tracing>

In this context, tracing allows us to evaluate how many and what kind of TCP/IP requests have been made to a database system. The two database systems involved in our test system are MinIO and PostgreSQL. MinIO is used as an object store, and PostgreSQL is used to persist data from the Hive Metastore (HMS). Initially, we also traced calls to PostgreSQL to better understand the HMS, before finding Thrift-based HMS clients (see @section_catalogs).

==== MinIO

MinIO allows the tracing of S3 API requests. This has been used, for example, to develop an understanding of how metadata is traversed to determine all relevant Parquet files when the specification is not clear.

Tracing can be started with `mcli admin trace [alias]`. The request listing is short and omits, among many other things, the boundaries of ranged requests. To include all HTTP headers of each request and response, the `-v` argument must be included: `mcli admin trace -v [alias]`.

`mcli admin trace` runs continuously in the foreground. The following construct can be used to trace specific queries:

```bash
mcli admin trace minio > trace.log &
TRACE_PID=$!
$TRINO_HOME/bin/trino --file=query.sql --output-format=NULL
kill -SIGINT $TRACE_PID
```

This snippet runs `mcli admin trace` in the background and uses the most recent background process ID as the recipient of `SIGINT` after the Trino client exits, interrupting the trace and writing the output to disk.
