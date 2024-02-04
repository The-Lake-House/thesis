#import "/flex-caption.typ" as flex

== Storage Formats <section_storage_formats>

The way data is written to disk is determined by the data placement strategy of the storage format. Strategies include row-oriented, column-oriented, or hybrid data placement.

A row-oriented data placement strategy writes data in row-major order, i.e., row by row. This is the model traditionally used for relational data because individual tuples can be extracted with a single seek @abadiDesignImplementationModern2009. Examples of row-oriented storage formats include CSV (a textual format), Apache Avro @ApacheAvro (a self-describing binary format), and to some extent SequenceFile @SequenceFile or HFile @HBASE61CreateHBasespecific (binary key-value formats).

Conversely, a column-oriented data placement strategy writes data in column-major order, i.e., column by column. This model is especially useful in OLAP where queries perform scans and aggregations over large portions of a few columns of a table because individual attributes can be extracted with a single seek. The contiguous attribute values are more compressible, cache-friendly, and can be vectorized @abadiDesignImplementationModern2009.

For large distributed data systems, where data can be partitioned across multiple nodes, a hybrid approach has been shown to provide the best of both worlds @heRCFileFastSpaceefficient2011. This is achieved by first partitioning the data horizontally (i.e., by rows) and then vertically (i.e., by columns). This model is inspired by PAX (Partition Attributes Across) @ailamakiWeavingRelationsCache2001. Examples include RCFile @heRCFileFastSpaceefficient2011, its successor Apache ORC @ApacheORC @huaiMajorTechnicalAdvancements2014, and Apache Parquet @ApacheParquet, all of which are binary. The latter two formats are self-describing and support nested data, a common requirement for data lakes that store large amounts of JSON, XML, or Protobuf files @melnikDremelInteractiveAnalysis2010. Self-describing formats embed the schema in the file so that the files can be read without knowing the binary structure in advance.

In this thesis, we focus on Apache Parquet because of its support for all table formats and execution engines. Zeng et al. compare both Apache Parquet and Apache ORC in detail @zengEmpiricalEvaluationColumnar2023.


=== Apache Parquet <parquet>

Parquet was announced in March 2013 as a joint project between Twitter and Cloudera engineers as a general-purpose columnar file format for Apache Hadoop @IntroducingParquetEfficient2013. It was donated to the Apache Software Foundation and became a top-level project in April 2015 @ApacheSoftwareFoundation. The specification is available on GitHub @ParquetFormatSpecification2024.

Data is partitioned horizontally into row groups, and vertically into column chunks, as shown in @figure_parquet_layout. Row groups have either a fixed size (e.g., 128 MiB in Trino by default) or a fixed number of rows (e.g., 1M rows in Apache Arrow by default). A fixed number of rows has the advantage of being easier to reason about, but the larger the number of columns, the fewer rows will fit in the same amount of space. Fixed blocks are appropriate for systems like HDFS that have a fixed internal block size. For object stores, this is less relevant as long as row chunks have roughly similar amounts of data to avoid poor resource utilization.

Column chunks contain contiguous values. Each column chunk is further partitioned into pages for compression and encoding. Nested data is supported via definition and repetition levels as described in Google's Dremel paper @melnikDremelInteractiveAnalysis2010.

#figure(
  image("/_img/parquet/file_layout.jpg"),
  caption: flex.flex-caption(
    [File layout of Apache Parquet @ParquetFormatSpecification2024],
    [File layout of Apache Parquet],
  ),
) <figure_parquet_layout>

At the end of each Parquet file is a footer that describes the file, each row group, and each column contained in each row group using the metadata hierarchy shown in @figure_parquet_metadata. Parquet is a binary format, and the footer is serialized using the `CompactProtocol` in Apache Thrift @ApacheThrift.

#figure(
  image("/_img/parquet/file_format.jpg"),
  caption: flex.flex-caption(
    [Metadata hierarchy of Apache Parquet @ParquetFormatSpecification2024],
    [Metadata hierarchy of Apache Parquet],
  ),
) <figure_parquet_metadata>

Parquet supports embedded statistics (`min_value`, `max_value`, `null_count`, `distinct_count`) at the level of column chunks or data pages. Different encoding types such as dictionary encoding and RLE (Run-Length Encoding) allow values to be stored in an efficient and compact way @ApacheParquetformatGitHube. There are also several compression codecs such as GZIP, ZStandard, and Snappy to compress data pages @ApacheParquetformatGitHubd.

Recently, two new features have been introduced @ApacheParquetformatGitHubb: column indexes to allow readers to skip pages more efficiently @ApacheParquetformatGitHubc, and Bloom filters as a compact alternative to dictionaries for high cardinality columns to allow predicate pushdown when dictionaries are deemed too large @ApacheParquetformatGitHuba. To our knowledge, column indexes are not yet used in Spark or in Trino.

Parquet is an open format, so many readers and writers have been developed. Commonly used are the reference implementation `parquet-mr` for MapReduce based systems in Java @ApacheParquetmr2024 and Apache Arrow @ApacheArrow, which has native implementations in several languages.
