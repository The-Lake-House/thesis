=== Read Path / Scan Planning <read_path>

In this subsection, we analyze the read path of each table format. Scan planning is the process of finding the files in a table that are needed for a query @IcebergPerformance. Analyzing the read path is useful for determining techniques for efficient data retrieval. The specifications are vague about how to perform scan planning on simple tables in object stores (see _Reader Expectations_ in @ApacheHudiTechnical for Hudi, _Scan Planning_ in @IcebergTableSpec for Iceberg, and _Action Reconciliation_ in @DeltaTransactionLog for Delta Lake).

We can partially determine the read path by tracing S3 requests (see @tracing). Scan planning has been partially reimplemented in Python code for better understanding. The code is available on GitHub at https://github.com/The-Lake-House/scan_planner. How data and log files are actually processed is beyond the scope of this subsection.

==== Hive

+ Get table object from HMS
+ If table is partitioned according to the `partition_columns` property of the table object, get partitions from HMS and add partition locations to list of locations, otherwise add table location to list of locations
+ For each location, list objects and add them to the list of data files

Partitions can also be discovered by listing all objects in the base directory. One file listing per partition is required.

==== Hudi

Scan planning in Hudi is comparatively complex due to the concept of file groups and file slices (see @metadata_concepts).

+ Get table object from HMS
+ Get `.hoodie/hoodie.properties` from table location
+ If `hoodie.table.partition.fields` exists in `.hoodie/hoodie.properties`, the table is partitioned and the value of the property is the partition key
+ List all objects in `.hoodie`
+ Get the latest commit file from the list of objects and extract the timestamp from it
+ If partitioned, list all objects in the base directory, extract the subdirectories, and add them to the list of locations
+ If not partitioned, add the table location to the list of locations
+ List objects for each location, then for each object
  + Determine by object name whether the object is a base file or a log file
  + Extract file ID and timestamp from object name
  + Skip objects with a timestamp greater than the latest timestamp
  + Add object to list of data files grouped by file ID
+ Sort data files for each file ID by timestamp in descending order
+ Collect log files for each file ID, stopping after encountering the first base file

==== Iceberg

+ Get table object from HMS
+ Get current table metadata from the `metadata_location` property of the table object
+ Get manifest list from path to manifest list of current snapshot
+ For each manifest extracted from the manifest list, if `status` is `1`, i.e., an addition, add the `data_file.file_path` to the list of data files

==== Delta Lake

+ Get table object from HMS
+ Check if `_delta_log/_last_checkpoint` exists at table location
+ If checkpoint exists, get checkpoint and apply it, then get Delta files starting from checkpoint
+ If checkpoint does not exist, get Delta files starting from `00000000000000000000`
+ Process actions
  - Extract `path` from `add` action in version file and add to list of data files
  - Extract `path` from `remove` action in version file and remove from list of data files
+ Repeat previous step for next Delta file until no more Delta files are found

There are two different approaches to determine the current version of a table: either list all objects in `_delta_log` and find the one with the highest version (see trace in @delta_current_version_list), or start at a certain point (e.g., 0, or from the last checkpoint) and count upwards (see trace in @delta_current_version_seq). The first approach is suggested by the specification and the behavior of the reference implementation, the second is implemented by Trino.

#figure(
```
[404 Not Found] s3.HeadObject 127.0.0.1:9000/data/_delta_log/_last_checkpoint
[404 Not Found] s3.HeadObject 127.0.0.1:9000/data/_delta_log
[200 OK] s3.ListObjectsV2 127.0.0.1:9000/?list-type=2&delimiter=%2F&max-keys=2&prefix=data%2F_delta_log%2F&fetch-owner=false
[200 OK] s3.ListObjectsV2 127.0.0.1:9000/?list-type=2&delimiter=%2F&max-keys=5000&prefix=data%2F_delta_log%2F&fetch-owner=false
[404 Not Found] s3.HeadObject 127.0.0.1:9000/data/_delta_log/00000000000000000001.crc
[200 OK] s3.HeadObject 127.0.0.1:9000/data/_delta_log/00000000000000000001.json
[200 OK] s3.HeadObject 127.0.0.1:9000/data/_delta_log/00000000000000000000.json
[206 Partial Content] s3.GetObject 127.0.0.1:9000/data/_delta_log/00000000000000000001.json
[206 Partial Content] s3.GetObject 127.0.0.1:9000/data/_delta_log/00000000000000000000.json
```,
caption: [Abridged trace log of read path for Delta Lake in Spark]
) <delta_current_version_list>

#figure(
```
[404 Not Found] s3.GetObject localhost:9000/data/_delta_log/_last_checkpoint
[206 Partial Content] s3.GetObject localhost:9000/data/_delta_log/00000000000000000000.json
[206 Partial Content] s3.GetObject localhost:9000/data/_delta_log/00000000000000000001.json
[404 Not Found] s3.GetObject localhost:9000/data/_delta_log/00000000000000000002.json
```,
caption: [Abridged trace log of read path for Delta Lake in Trino]
) <delta_current_version_seq>


==== Conclusions

Metadata traversal is $O(1)$ in the best case, i.e., it always takes the same time regardless of how many previous versions there are. This is the case for Iceberg, but it comes at a cost: the individual snapshots can get quite large. Delta Lake uses an $O(n)$ approach, which can be made faster by using checkpoints, as shown in @delta_checkpointing. Hudi can derive its entire version history from a few, but expensive, file listing requests. The cost of this should be reduced with both the Hudi metadata table and the timeline server, but as we observed in @hudi_file_caching, this may not be the case.

Tables can be partitioned, and this must be taken into account: some formats, such as Iceberg and Delta Lake, do this transparently by including the partition path in the metadata of each data file, others require extra work to resolve files in partitions.
