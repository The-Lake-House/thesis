#import "/flex-caption.typ" as flex

=== Metadata Concepts <metadata_concepts>

This subsection provides an overview of how tables are versioned on a conceptual level. In the next subsection, we analyze what actually happens during table creation and during operations such as inserts, deletes, and updates in Spark and Trino. This is the basis for further features such as statistics and Bloom filters, which are expressed as auxiliary metadata.

Essentially, all table formats are directories of data files plus metadata. The differences are the where the metadata is stored, how the metadata is structured, and how the metadata reflects table changes.

In addition to the metadata structures introduced here, each table is also listed in the catalog, e.g., the Hive Metastore (HMS). We consider the base directory to be the storage location of the table listed in the HMS. A snapshot represents the current state of the table @IcebergTableSpec.

Table formats typically support Hive-style partitioning, where partitions are expressed using subdirectories named by the partitioning column and partitioning value. Partitions can be nested.

==== Hive

Hive takes a different approach than other table formats: It is just a directory of files, without metadata files. The names of the data files are meaningless. Metadata is managed centrally and independently of the underlying storage system in the HMS. Since Hive does not need to keep track of versions, metadata management is also simplified. Individual data files are not tracked in the HMS, and can only be discovered using inefficient file listings (see @read_path). Partitions are listed in the HMS but can also be discovered using file listings starting from the base directory.

==== Hudi

Hudi has the concept of file groups and file slices (see _File Layout Hierarchy_ in @ApacheHudiTechnical). A file group is an ordered collection of file slices with the same file ID. The file ID is a randomly generated string. A file slice consists of a base file, or a base file and all log files associated with that base file. File slices are identified by their timestamp. The current file slice of each file group is used to answer queries, unless time travel is performed.

Each data file is named according to the following scheme: `[File ID]_[File Write Token]_[Transaction Timestamp].[File Extension]`.

File IDs and timestamps are enough metadata to build a graph of changes.

In general, all change operations correspond to the creation of new file slices for existing file groups.

In CoW, all change operations work by copying the base file of the current file slice of a file group, applying the changes, and writing the new base file as a new file slice.

In MoR, all change operations work by adding a log file to the current file slice of a file group.

Log files are hidden and their names have the following structure: `.[File Id]_[Base Transaction Timestamp].[Log File Extension].[Log File Version]_[File Write Token]`.

Log files are in a Hudi native container format described in _Log File Format_ in @ApacheHudiTechnical, containing Avro, Parquet, or HFile files.

File slices can be empty: if all of the records of a file group are deleted, an empty Parquet file is left behind.

Hudi creates a hidden directory called `.hoodie` in the base directory. All metadata files created by Hudi are hidden: this may be a holdover from HDFS, as object stores do not support hidden files.

The `.hoodie` directory contains `hoodie.properties`, which lists table metadata, including the table type (`hoodie.table.type`: `COPY_ON_WRITE` or `MERGE_ON_READ`), the table version (`hoodie.table.version`: `6`), and other information @ApacheHudiGitHubc.

Changes to a table are tracked in the form of commits in the `.hoodie` directory. There are two types of commit files: `commit` files for Copy-on-Write tables, and `deltacommit` files for Merge-on-Read tables. Before a commit is persisted, there are two intermediate files: `requested` and `inflight` files. These are used for rollbacks @ApacheHudiGitHubg.

CoW has `commit` files with three states: `commit.requested`, `inflight`, and `commit`. `commit.requested` is an empty file, but the filename carries meaning by containing the timestamp. The `inflight` file and the `commit` file contain the same set of metadata fields: `partitionToWriteStats`, `compacted`, `extraMetadata`, `operationType`. `partitionToWriteStats` is more detailed in `commit`.

MoR has `deltacommit` files with three states: `deltacommit.requested`, `deltacommit.inflight`, and `deltacommit`. `deltacommit.requested` is an empty file, but the filename carries meaning by containing the timestamp. `deltacommit.requested` has `operationType` and write statistics that contain null or 0 values for all fields except `numInserts`. `deltacommit` has fully specified write stats. Write statistics are divided by partitions. If there are no partitions, the partition name is specified as `""`. Write statistics are an array, one for each file added (`fileId`, `path`, `fileSizeinButes`, ...).

Interestingly, CoW inflights do not contain the word `commit` in their name, while MoR inflights contain the word `deltacommit`.

`requested` and `inflight` files are not deleted once the transaction is committed.

Despite the large amount of metadata in `commit` and `deltacommit` files, it is not possible to reconstruct the current snapshot from them. However, they do contain a timestamp in the file name that can be used to determine possible snapshots. See @read_path for more information.

The `.hoodie` directory also contains a `metadata` directory: this is the Hudi metadata table, a Hudi table within a Hudi table that serves as a location for multimodal indices (see _Metadata_ in @ApacheHudiTechnical). Since this table is a full Hudi table, it also contains its own `.hoodie` subdirectory, etc. Internally, it is a MoR table backed by HFiles. The Hudi metadata table contains several partitions, each representing a different index @ApacheHudiGitHubd. We will discuss these indices in @indexing, @hudi_file_caching, and @table_statistics. The metadata table can be completely disabled with `hoodie.metadata.enable=false`.

==== Iceberg

Within the base directory, there are two subdirectories: `data` and `metadata`. As the names suggest, `data` contains the data files, and `metadata` contains the metadata files. There are several types of metadata files that form a hierarchy as shown in @iceberg_metadata_hierarchy: table metadata files, manifest files, and manifests.

#figure(
  image("/_img/iceberg-metadata.png"),
  caption: flex.flex-caption(
    [Iceberg metadata hierarchy @IcebergTableSpec],
    [Iceberg metadata hierarchy],
  ),
) <iceberg_metadata_hierarchy>

Each data file is described by a manifest file, which contains the location and statistics of the file. Manifest files are grouped into a manifest list, which represents all the data files contained in a snapshot. All snapshots are listed in the table metadata files, including other table metadata. Each snapshot has its own manifest list, but can reuse previous manifest files.

The table metadata files are JSON files that begin with a five-digit, zero-padded sequential number (e.g., `00000`) (see _Appendix C: JSON serialization_ in @IcebergTableSpec). Notable fields are `format-version`, `properties`, `current-snapshot-id`, `snapshots`, `snapshot-log`, and `metadata-log`. `properties` is a nested JSON object containing table properties such as `write.merge.mode`, `write.delete.mode`, `write.update.mode`, and other table properties (see @table_types). `snapshots` is an array containing snapshot objects. Notable fields of a snapshot are `snapshot-id` and `manifest-list`. `manifest-list` provides the path to the manifest list for that snapshot. `current-snapshot-id` contains the `snapshot-id` of the current snapshot. `snapshots` can be used for time travel.

The manifest lists are Avro files starting with `snap-` (see _Snapshots_ in @IcebergTableSpec). Each record describes a manifest. Notable columns include `manifest_path`, `content`, `added_data_files_count`, `deleted_data_files_count`, `added_rows_count`, and `deleted_rows_count`. `content` indicates whether the file tracked by the manifest is a data file (`0`) or a delete file (`1`). `manifest_path` provides the path to the manifest.

The manifests are also Avro files ending in `-mX.avro` where `X` is an integer. Notable columns include `status` and `data_file`. Each change to a data file becomes a new manifest file: if a data files is added, the `status` is `1`; if a data file is removed, the `status` is `2`. Metadata about the data file is tracked in the `data_file` column, specifically: `content`, `file_path`, `record_count`, `file_size_in_bytes`, `value_counts`, `null_value_counts`, `nan_value_counts`, `lower_bounds`, and `upper_bounds`. `content` describes the content stored by the data file: data (`0`), position deletes (`1`), or equality deletes (`2`).

The manifest lists and manifests can be viewed using the `avrocat` script described in @avrocat.

To find the most recent snapshot, we can find the most recent table metadata file, either by file listing or, more typically, by embedding the most recent snapshot in the HMS.

Iceberg is the only table format that formalizes the use of a catalog. Here we focus on the HMS as a catalog, but there are other Iceberg-specific implementions @IcebergCatalogs. For a given database and table, the catalog contains the path to the current metadata location.

==== Delta Lake

Delta Lake takes a different approach than Iceberg: Versions are sequentially tracked as JSON Lines files @JSONLines in a directory called `_delta_logs` in the base directory. These files are called Delta files. The names of the Delta files are sequential numbers starting with 0 and padded with `0` to 20 digits. They are padded so that `LIST` requests to object stores, which are typically lexicographically sorted, can only request files starting from the last checkpoint @armbrustDeltaLakeHighperformance2020. To find the sequence number of the current snapshot, we either count up from 0 until the Delta file could not be found, or we use a file listing from the `_delta_logs` directory @armbrustDeltaLakeHighperformance2020.

Delta files stripped of whitespace, which makes them slightly more compact at the expense of legibility. We found that the best way to view them is with the jq tool @Jq: `jq --slurp '.' 00000000000000000000.json`.

This linked-list approach to metadata management is quite simple, and the cost of reconstruction can be high. Checkpointing is a mechanism to address some of its shortcomings (see @scalability_table_formats).

Each Delta file contains one or more _actions_, each of which is described in a JSON document on a separate line. Common actions are `metaData`, `add`, `remove`, `protocol`, and `commitInfo`.

The first version of a table must contain a `metaData` action specifying, among other things, the `id`, `format`, `schemaString`, `partitionColumns`, and `configuration` of the table (see _Change Metadata_ in @DeltaTransactionLog). Every table must also contain a `protocol` action describing `minReaderVersion` and `minWriterVersion` (see _Protocol Evolution_ in @DeltaTransactionLog).

The `add` action adds data files to the table, and the `remove` action removes them (see _Add File and Remove File_ in @DeltaTransactionLog).

`commitInfo` contains optional commit provenance information (see _Commit Provenance Information_ in @DeltaTransactionLog).

==== Conclusions

Hudi builds on Hive's directory of files approach and manages to express relationships between files using only their file names by introducing the concept of file groups, file slices, and timestamps. Given that metadata files are hidden, file names generated by Spark and Trino already have pseudo-random components in them, and the fact that the `.hoodie` directory contains a wealth of auxiliary information, we found it difficult to figure out this comparatively simple mechanism by observation alone, without reading the specification. A custom format is used for log files and there is currently no command-line tool for reading them.

Iceberg has the most verbose metadata schema. There is a lot of redundancy in the format, and it doesn't help that except for table metadata files, all files have randomly generated names and are in Avro format. Despite the hierarchical structure, we found it cumbersome to follow the metadata trail, especially for MoR tables. On the plus side, MoR-based log files are written in open formats and are easy to inspect. Manifest lists can grow quickly and need to be compacted frequently (see @table_maintenance).

Delta Lake has the most intuitive directory structure: there is a clear separation between data files and log files, and the log files are in a text-based format. The log files are stored in JSON Lines format with no whitespace. JSON prettifiers must support the JSON Lines format to make them readable.
