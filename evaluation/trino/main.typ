== Trino-Specific Optimizations <trino_optimizations>

During our analyses we found two Trino-specific optimizations that are not often talked about: determining the ideal split size and determining the ideal Parquet file size. 

#include "split_size.typ"

#include "parquet_size.typ"
