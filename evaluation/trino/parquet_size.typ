#import "/flex-caption.typ" as flex

=== Ideal Parquet Size Determination <parquet_size_determination>

There is a consensus that the small files problem is bad and should be avoided @aggarwalSmallFilesProblem2022, but, there is no consensus on the ideal size of a Parquet file. As described in @file_sizes, there are different limits on the maximum file size.

Conceptually, multiple reads are required to read a Parquet footer: the first one extracts the last 4 bytes of the Parquet file containing the magic code (`PAR1`) to verify that the file is indeed a Parquet file. The next one reads the 4 bytes before the magic code. This is the length of the footer. Based on this length, the entire footer can finally be read and parsed.

In Trino, these three requests are combined into a single request. There is a heuristic that assumes that the footer is not larger than 48 KiB @TrinodbTrinoGitHubc.

We analyzed under which conditions the 48 KiB limit is exceeded by varying the number of row groups and columns. A random matrix with an increasing number of rows and columns containing IEEE-754 doubles was generated using NumPy and persisted as a Parquet file using `pyarrow` @PythonApacheArrow. The Parquet files were written with a single row group per input row. The size of the row group metadata in the footer is independent of the actual number of values stored in the row group.

#figure(
  image("/_img/ideal_parquet_size/plot_double.svg"),
  caption: flex.flex-caption(
    [The maximum combination of row groups and columns to fit in a 48 KiB Parquet footer],
    [Max row groups and columns in a 48 KiB Parquet footer],
  ),
)

We noticed that row groups are lighter than columns. This is because statistics are stored at the column level. The storage size of a row group is proportional to the number of columns. A Parquet footer can contain a maximum of 421 row groups with a single double column, or 116 columns with a single row group.

If the 48 KiB optimization is representative of an ideal Parquet size, then the range of possible file sizes is quite large: from 128 MiB (1 row group with 116 columns) to 52.625 GiB (421 row groups \* 128 MiB). This calculation assumes the common row group size of 128 MiB, which is also not fixed.

For some OLAP datasets, especially those using a star schema, this heuristic is not ideal, but it saves two requests for smaller datasets.

This analysis did not consider other data types that may be more or less efficient to store, assuming that doubles are the most common data type for data analysis purposes.
