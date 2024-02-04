= Evaluation <evaluation>

After familiarizing ourselves with the inner workings of common table formats in @comparison, we now test their performance empirically. First, we introduce benchmarks and benchmark metrics in @methods, then we perform an initial comparison using queries from the TPC-H benchmark in @tpch_benchmark, and finally we look at a more detailed comparison based on a minimal dataset in @scalability_table_formats. We also cover special topics such as a MinIO performance test in @scalability_object_storage, an analysis of S3 request types in @request_types, and Trino-specific optimizations in @trino_optimizations.

#include "methods/main.typ"

#include "tpch_benchmark.typ"

#include "scalability_table_formats.typ"

#include "mitigations.typ"

#include "scalability_object_storage.typ"

#include "request_types.typ"

#include "trino/main.typ"
