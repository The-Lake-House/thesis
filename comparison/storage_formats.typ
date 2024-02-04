=== Storage Formats <supported_storage_formats>

Table formats can support multiple storage formats for data files. The choice of storage format is made when the table is created and cannot be changed after it is made. The specification lists which file formats are officially supported, but support in execution engines may vary. Execution engines also typically select a default storage format.

==== Hive

Hive supports the most storage formats: Text, SequenceFile, RCFile, Avro, ORC, and Parquet, as well as custom input and output formats @ApacheHiveFileFormats.

In Spark, all are supported @SparkDocumentationHive, and the format can be set by adding `OPTIONS (fileFormat = 'FORMAT')` to the `CREATE TABLE` statement. Interestingly, the default storage format for Hive in Spark is `textfile`.

Trino supports some additional formats @TrinoDocumentationHive: `JSON`, `CSV`, and `REGEX`. RCFile file support is split into `RCBINARY` and `RCTEXT`. The storage format can be changed using the catalog property `hive.storage-format`, or by adding `WITH (format = 'FORMAT')` to the `CREATE TABLE` statement. There is also a session property called `hive.hive_storage_format`, but it is currently not respected for tables, only for partitions, and only if `hive.respect_table_format` is set to `false` @TrinodbTrinoGitHubg. The default storage format is `ORC`.

The names of the data files are meaningless.

==== Hudi

Hudi supports Parquet, ORC, and HFile @ApacheHudiTechnical. Spark supports all of them, but Trino can only read tables using Parquet files @TrinoDocumentationHudi.

The names of the data files are critical to identifying file groups and their associated file slices.

While the other table formats leave the data files as they are, Hudi adds additional columns to each data file: `_hoodie_commit_time`, `_hoodie_commit_seqno`, `_hoodie_record_key`, `_hoodie_partition_path`, and `_hoodie_file_name`, all stored as `STRING`. Furthermore, Hudi also adds a Bloom filter to the Parquet file properties by default (see @indexing). For small tables, the extra metadata is noticeable: a Parquet file with two columns and a single row weighs 669 bytes when generated as a Hive table, and 434531 bytes as a Hudi table (of which 431381 bytes are used by the Bloom filter).

Another difference to other table formats is that Parquet files can be empty: file groups can end up with zero records, and since there are no metadata files, there is no way to set a tombstone other than writing an empty file. In other formats, this would be reflected in the metadata without writing an empty file.

==== Iceberg

Iceberg supports Parquet, ORC, and Avro @IcebergTableSpec.

In Spark, the storage format can be changed using the `write.format.default` table property @IcebergWriteProperties.

In Trino, the storage format can be changed with the catalog configuration parameter `iceberg.file-format`, or by adding `WITH (format = 'FORMAT')` to the `CREATE TABLE` statement.

Both execution engines support all storage formats and default to Parquet.

The names of the data files are meaningless.

==== Delta Lake

Delta Lake currently only supports Parquet @DeltaTransactionLog, but the team is considering adding other storage formats @DeltaioDeltaGitHube.

The names of the data files are meaningless.

==== Conclusions

Each table format relies on one or more underlying storage formats to store table data. The standards do not propose any of the listed storage formats as the default, but implementations typically must choose one. Parquet is the only storage format supported by all table formats. Typically, data files are left as they are, except for Hudi, which adds additional columns.

In addition to storage formats for data files, there are also formats for expressing changes in MoR tables. These are described in @section_delete_semantics.
