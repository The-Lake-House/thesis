= Tools <tools>

== `parquet_num_rows`

`parquet_num_rows` is a script that displays the number of rows of a Parquet file. It uses `pyarrow` @PythonApacheArrow to read the Parquet file.

```python
#!/usr/bin/env python

import sys

import pyarrow
import pyarrow.parquet

if len(sys.argv) < 2:
    print("Usage: get_parquet_num_rows FILE", file=sys.stderr)
    sys.exit(1)

metadata = pyarrow.parquet.read_metadata(sys.argv[1])
print(metadata.num_rows)
```


== `parquet_row_group_sizes`

`parquet_row_group_sizes` is a script that displays the row group sizes of a Parquet file. It uses `pyarrow` @PythonApacheArrow to read the Parquet file.

```python
#!/usr/bin/env python

import sys

import pyarrow
import pyarrow.parquet

if len(sys.argv) < 2:
    print("Usage: get_row_group_sizes FILE [UNIT]", file=sys.stderr)
    sys.exit(1)

def size_format(num_bytes, unit):
    if unit == "GiB":
        return num_bytes / pow(1024, 3)
    if unit == "MiB":
        return num_bytes / pow(1024, 2)
    if unit == "KiB":
        return num_bytes / 1024
    else:
        return num_bytes

if len(sys.argv) == 3:
    unit = sys.argv[2]
    if unit not in ["GiB", "MiB", "KiB", "B"]:
        print("UNIT has to be one of GiB, MiB, KiB, B", file=sys.stderr)
        sys.exit(1)
else:
    unit = "B"

metadata = pyarrow.parquet.read_metadata(sys.argv[1])
for i in range(metadata.num_row_groups):
    row_group = metadata.row_group(i)
    compressed = 0
    uncompressed = 0
    for j in range(row_group.num_columns):
        column = row_group.column(j)
        compressed = compressed + column.total_compressed_size
        uncompressed = uncompressed + column.total_uncompressed_size
    if uncompressed != row_group.total_byte_size:
        print("total_byte_size does not match sum of uncompressed column sizes", file=sys.stderr)
        sys.exit(1)
    print(f"{i}: {size_format(compressed, unit)} {unit} compressed / {size_format(uncompressed, unit)} {unit} uncompressed")
```


== `parquetcat`

`parquetcat` is a script to display the contents of a Parquet file. It uses `parquet-cli`, part of `parquet-mr` @ApacheParquetmr2024.

```bash
#!/usr/bin/env bash

parquet-cli cat "$1"
```


== `avrocat` <avrocat>

`avrocat` is a script to display the contents of an Avro file in JSON format.  It uses `avro-tools`, part of `avro` (in `lang/java/tools` @ApacheAvro2024), and `jq` @Jq.

```bash
#!/usr/bin/env bash

avro-tools tojson "$1" | jq '.'
```


== `minisize`

`minisize` is a script to improve the startup of the Trino development server by removing unneeded plugins from plugin.bundles in `testing/trino-server-dev/etc/config.properties` and by removing unneeded catalogs from `testing/trino-server-dev/etc/catalogs` and configuring the desired ones.

The code is available on GitHub at https://gist.github.com/agrueneberg/f0a3986a35888f1ac67ab529bf99e26c.
