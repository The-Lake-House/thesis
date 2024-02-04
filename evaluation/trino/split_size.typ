#import "/flex-caption.typ" as flex

=== Ideal Split Size Determination <split_size_determination>

When we first benchmarked TPC-H Q1 on a 4 core desktop (see @tpch_benchmark), we found that for a scale factor of 2 Hive and Delta Lake were significantly faster than Iceberg.

#figure(
  table(
    columns: 4,
    [*Table Format*], [*N*], [*Mean Time [ms]*], [*Standard Deviation [ms]*],
    [Hive], [25], [697], [25.8],
    [Hudi], [25], [1458], [19.6],
    [Iceberg], [25], [1239], [21.2],
    [Delta Lake], [25], [692], [15.8],
  )
)

The runtime is too short to capture useful patterns in `sar`, but we noticed different `Input avg.`s in the query plans.

After some investigation, we traced the differences back to split generation. As discussed in @split_generation, Iceberg uses a constant split size of 128 MiB, while Hive and Delta Lake use 32 MiB for the first 200 splits and then 64 MiB for the remaining splits.

A review of the `ConnectorSplitManager` implementations of Hive, Delta Lake, and Iceberg revealed that each found Parquet file is split into evenly sized / uniform splits (see @uniform_splitting_32_ideal). These splits are then distributed to the workers as a tuple of file path, offset, and length @TrinodbTrinoGitHuba.

Each worker reads the footer of the Parquet file at the file path and checks if a new row group starts within the range of offset and offset + length. For the Parquet reader in Trino, the row group is an indivisible unit. If a new row group starts, the split is passed for further processing, otherwise it is considered empty.

#figure(
  image("/_img/split_generation/32_ideal.svg"),
  caption: flex.flex-caption(
    [Example of uniform splitting using a 32 MiB initial split size on 128 MiB row groups. Arrows indicate splits that will be passed on for further processing.],
    [Uniform splitting: 32 MiB split size],
  ),
) <uniform_splitting_32_ideal>

Next, we tried setting a consistent split size of 128 MiB in Hive and Delta Lake (see @split_generation), which should produce three non-empty splits (see @uniform_splitting_128_ideal). Hudi was excluded because the split size is fixed ( see @split_generation).

#figure(
  image("/_img/split_generation/128_ideal.svg"),
  caption: flex.flex-caption(
    [Example of uniform splitting using a consistent 128 MiB split size on 128 MiB row groups. Arrows indicate splits that will be passed on for further processing.],
    [Uniform splitting: 128 MiB split size on row groups = 128 MiB],
  ),
) <uniform_splitting_128_ideal>

#figure(
  table(
    columns: 4,
    [*Table Format*], [*N*], [*Mean Time [ms]*], [*Standard Deviation [ms]*],
    [Hive], [25], [1219], [24.0],
    [Iceberg], [25], [1239], [21.2],
    [Delta Lake], [25], [1224], [20.0],
  )
)

Performance is now similar between Hive, Iceberg, and Delta Lake. However, Hive and Iceberg actually got slower, even though they produced fewer empty splits, i.e., less extra work.

Looking at the row group sizes using the `parquet_row_group_sizes` tool (see @tools), we can see that the row group sizes are far from the 128 MiB / 131072 B limit:

```bash
$ parquet_row_group_sizes 20240102_120810_00010_knwi9_11e68a82-37c1-4c6f-8d01-1ada51223341
0: 125701139 B compressed / 322813139 B uncompressed
1: 125702325 B compressed / 322831292 B uncompressed
2: 46892357 B compressed / 118659205 B uncompressed
```

A split size of 128 MiB on row groups smaller than 128 MiB results in splits responsible for multiple row groups, as shown in @uniform_splitting_128_real, limiting parallelism. And indeed, after tracing which threads each split is mapped to using a custom `PageSourceProvider`, we confirmed that one thread is indeed handling two row groups.

#figure(
  image("/_img/split_generation/128_real.svg"),
  caption: flex.flex-caption(
    [Example of uniform splitting using a consistent 128 MiB split size on row groups smaller than 128 MiB. Arrows indicate splits that will be passed on for further processing.],
    [Uniform splitting: 128 MiB split size on row groups < 128 MiB],
  ),
) <uniform_splitting_128_real>

In general, the ideal split size can be calculated as the file size divided by the number of row groups, assuming that the row group sizes are roughly equal. In our particular case this would be 298,301,260 B / 3 row groups = 99,431,940 B, but the last smaller row group skews this average too far down. So we use 120,000,000 B, which is about 118 MiB.

In this particular case of three splits and four cores, this split size results in the best performance across all table formats because all cores are used.

#figure(
  table(
    columns: 4,
    [*Table Format*], [*N*], [*Mean Time [ms]*], [*Standard Deviation [ms]*],
    [Hive], [25], [683], [21.8],
    [Iceberg], [25], [704], [19.8],
    [Delta Lake], [25], [679], [16.3],
  )
)

*Conclusion*: The default initial split size of 32 MiB and the regular split size of 64 MiB in Hive and Delta Lake are too small for Parquet files, resulting in empty splits. The split size of 128 MiB in Iceberg is too large for Parquet files, causing tasks to work on multiple row groups. The ideal split size for Parquet files using the default row group size of 128 MiB is somewhere between 64 MiB and 128 MiB. We have found a split size of 118 MiB to be ideal, minimizing empty splits and maximizing parallelism.

This recommendation may work in controlled environments where Parquet files with a fixed row group size can be guaranteed, but in the wild, Parquet files may have unbalanced row groups. While evenly-sized row groups are desirable as a unit of parallelism @ParquetFormatSpecification2024, there seems to be no consensus within the Parquet community as to whether these row groups should be created using a fixed size (an approach often found in the Hadoop ecosystem due to the HDFS block abstraction) or a fixed number of lines (an approach taken by pyarrow @PythonApacheArrow).

Since the fixed size limit tracks compressed data, and column chunks are written in pages (of variable length), it is difficult to produce evenly-sized row groups without padding. As for the fixed number of lines, it is difficult to reason about the actual storage requirements in advance (a problem related to the Parquet footer optimization described in @parquet_size_determination).

Instead of using a fixed split size, splits along row groups could be generated by the coordinator during query planning. This could be done either by retrieving the Parquet footer during scan planning, or by adding row group offsets to the table metadata, an approach suggested by Iceberg with its `split_offsets` in the manifest files @IcebergTableSpec, which is not yet implemented in Trino @TrinodbTrinoGitHubb.

The current approach to split generation in Trino is storage format agnostic. It works best with textual files, but is not necessarily helpful with the storage formats commonly used with lakehouse table formats @TrinodbTrinoGitHubd.

There is only one coordinator in Trino, and care must be taken not to overload it with too much additional metadata processing. The scan planning described in @read_path is required for the coordinator to perform query planning, but split handling can be delegated to the workers. The potential for empty splits leads to more requests to the object store, resulting in both access and egress charges for the footer transfer, but this may be acceptable to keep the query planning stage simple. In addition, the potential cost of having a task deal with multiple row groups may be negligible for large workloads, especially in environments with multiple parallel queries.
