=== Query Plans <query_plan>

Query plans allow us to understand the decisions made by the query planner and query optimizer and to gain insight into how data is flowing through the system to check for bottlenecks, whether pushdowns are working correctly, and so on.

In Trino, the distributed query plan of a query can be viewed using `EXPLAIN (TYPE DISTRIBUTED) QUERY_STRING;` or simply `EXPLAIN QUERY_STRING;`. Neither of these commands executes the query, they will only display the query plan.

Distributed query plans are split into stages, called fragments. There are several types of fragments. In this manuscript, we focus mainly on `SOURCE` fragments, because these are the ones responsible for getting data into the system by reading it, in our case, from lakehouse tables. The data is then passed to other fragments via pages, a column-oriented collection of elements, using a `RemoteSource` task.

Distributed query plans are read from bottom to top. Each task has an `Estimates` field that lists the estimated number of input rows (`rows`), CPU time (`cpu`), memory (`memory`), and network (`network`). If the values are specified as '`?`', the system is unable to provide an estimate for this task.

There is also `EXPLAIN ANALYZE`, which annotates the query plan with the cost of each operation _after_ the query is executed. Important fields here for each task are `Estimates`, `CPU`, `Input`, and `Input avg.`.

`CPU` lists the actual CPU time (`system` + `user`), the scheduled time (the difference between the end and start of a task), and the number of rows of output produced. If the difference between the scheduled time and the CPU time is large, this may be an indication that the system is I/O bound (e.g., as observed in @tpch_query1_sf100):

```
CPU: 55.66s (78.73%), Scheduled: 9.92m (97.33%), Blocked: 0.00ns (0.00%), Output: 591599349 rows (29.20GB)
```

`Input` lists the actual number of rows that were processed and the percentage of rows filtered out:

```
Input: 600037902 rows (27.64GB), Filtered: 1.41%, Physical input: 4.16GB, Physical input time: 8.89m
```

`Input avg.` shows the average number of rows processed by each task:

```
Input avg.: 1714394.01 rows, Input std.dev.: 127.38%
```
