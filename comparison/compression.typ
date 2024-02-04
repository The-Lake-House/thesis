=== Compression Codecs <supported_compression_codecs>

The compression codecs supported by table formats are not determined by the table format, but by the underlying storage format. Parquet supports a wide range of compression codecs: `UNCOMPRESSED`, `SNAPPY`, `GZIP`, `LZO`, `BROTLI`, `LZ4`, `ZSTD`, `LZ4_RAW` @ApacheParquetformatGitHubd.

In Trino, the compression codec varies depending on the connector, as shown in @trino_default_compression_codecs.

#figure(
  table(
    columns: 2,
    align: left,
    [*Table Format*], [*Default Compression*],
    [Hive], [gzip],
    [Hudi], [N/A],
    [Iceberg], [zstd],
    [Delta Lake], [snappy],
  ),
  caption: [Default compression codecs in Trino],
) <trino_default_compression_codecs>

Spark defaults to `SNAPPY` for Parquet files @SparkParquet, but this can be ignored by plugins as shown in @spark_default_compression_codecs.

#figure(
  table(
    columns: 2,
    align: left,
    [*Table Format*], [*Default Compression*],
    [Hive], [None],
    [Hudi], [gzip @HudiAllConfigurations],
    [Iceberg], [gzip @IcebergWriteProperties],
    [Delta Lake], [`spark.sql.parquet.compression.codec` or `compression` storage option, i.e., snappy],
  ),
  caption: [Default compression codecs in Spark],
) <spark_default_compression_codecs>

The compression codec can be set with the `spark.sql.parquet.compression.codec` property or the `compression` storage option in the `CREATE TABLE` call in Spark and `CATALOG.compression-codec=CODEC` as a catalog configuration property or `CATALOG.compression_codec = CODEC` as a session property in Trino.
