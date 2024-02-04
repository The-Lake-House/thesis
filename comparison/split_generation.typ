=== Split Generation <split_generation>

Once the data files belonging to the current table snapshot have been identified (see @read_path), they are split into smaller subunits and sent to workers for processing. In Trino, this split generation mechanism is storage format agnostic and splits data files uniformly. The default split sizes vary depending on the table format, as shown in @default_split_sizes.

#figure(
  table(
    columns: 2,
    align: left,
    [*Table Format*], [*Split Size*],
    [Hive], [32 MiB for the first 200 splits, 64 MiB afterwards],
    [Hudi], [Entire file],
    [Iceberg], [128 MiB],
    [Delta Lake], [32 MiB for the first 200 splits, 64 MiB afterwards],
  ),
  caption: [Default split sizes],
) <default_split_sizes>

There are several ways to set the split size.

==== Hive

Catalog configuration properties:

- `hive.max-initial-splits=200` 200 initial splits
- `hive.max-initial-split-size=(half of hive.max-split-size)` @TrinodbTrinoGitHubj
- `hive.max-split-size=64MB`

Session properties (not documented):

- `hive.max_split_size` max splits size @TrinodbTrinoGitHubl
- `hive.max_initial_split_size` @TrinodbTrinoGitHubk

==== Hudi

Hudi seems to use the file length as the split size when used with object stores. By default, the block size is the block size of the file @TrinodbTrinoGitHubm, which is set to `max(blockSize(fileEntry.blocks()), min(fileEntry.length(), MIN_BLOCK_SIZE))` @TrinodbTrinoGitHubn. Object stores do not have the concept of blocks, and files are therefore initialized as a single block that spans the entire file. We expected `blockSize` to be `0` here and `MIN_BLOCK_SIZE` to be used, which defaults to 32 MiB, but this does not seem to be the case. Incidentally, the default maximum file size of a Parquet file created by Hudi is 128 MiB, so this behavior may be intentional.

==== Iceberg

The split size can be changed with the hidden `iceberg.experimental_split_size` session property. There is no corresponding configuration property.

==== Delta Lake

Catalog configuration properties:

- `delta.max-initial-splits=200` 200 initial splits
- `delta.max-initial-split-size=(half of hive.max-split-size)` @TrinodbTrinoGitHubo
- `delta.max-split-size=64MB`

Session properties (not documented):

- `delta.max_split_size` @TrinodbTrinoGitHubp
- `delta.max_initial_split_size` @TrinodbTrinoGitHubq

==== Conclusions

Not only the split size, but also the way splits are generated can vary from one table format to another. Split can be generated serially or in parallel. Hive and Hudi generate splits in parallel, one per partition. This is because they rely on directory listings, which are blocking calls. Iceberg and Delta Lake generate splits serially.

The effects of split generation are examined further in @split_size_determination.
