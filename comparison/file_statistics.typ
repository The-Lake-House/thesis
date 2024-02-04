==== Statistics <file_statistics>

Statistics can be embedded in Parquet files at the level of column chunks or data page headers @ApacheParquetformatGitHub. These statistics can be used to perform data skipping. Data skipping reduces I/O for SQL queries by skipping irrelevant data objects (files) based on their metadata @ta-shmaExtensibleDataSkipping2020. For example, if a predicate targets a particular attribute value and that value is not in the row group or page, that row group or page can be skipped.

The following values can be collected: `null_count`, `distinct_count`, `max_value`, `min_value`, `is_max_value_exact`, `is_min_value_exact`. Regardless of these optional fields, each file is guaranteed to contain `num_rows` for each file (`FileMetaData`), `total_byte_size` for each row group (`RowGroup`), and `num_values`, `total_uncompressed_size`, `total_compressed_size` for each column in each row group (`ColumnMetaData`).

The metadata collected is similar to zone maps or synposis tables found in other database management systems. Data skipping based on minimum and maximum values may only be effective if the data has some natural or imposed clustering (see @data_layout).

Data skipping in Parquet is enabled by default in Spark. It can be disabled by unsetting `spark.sql.parquet.filterPushdown`. It is also enabled by default in Trino.
