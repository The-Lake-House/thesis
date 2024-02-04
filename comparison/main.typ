= Comparison <comparison>

In this chapter we compare the table formats introduced in @section_table_formats in more detail.

At first glance, all modern table formats have a lot in common: they all support inserts, deletes, updates, and merges in an atomic, isolated, and durable manner, different ways of ingesting changes (CoW, MoR), time travel, schema enforcement and evolution, etc. on a set of data files in a particular storage format. But each feature is implemented in a different way, making evaluation difficult.

In this manuscript, we focus mainly on issues along the read path for each table format: metadata management, use of data files, and optimizations. The metadata of each table format is discussed in the first section, @metadata_management. This is followed by a brief comparison of storage format support in the second section, @data_files, and performance optimizations in the third section @optimizations.

== Metadata Files <metadata_management>

A table format is a metadata layer on top of data files in a particular storage format. In this section, we compare how this metadata is managed when changes are being made to a table, based on the specification and our observations in different execution environments.

#include "specification.typ"

#include "configuration.typ"

#include "table_types.typ"

#include "metadata_concepts.typ"

#include "create_table_semantics.typ"

#include "insert_semantics.typ"

#include "delete_semantics.typ"

#include "update_semantics.typ"

#include "read_path.typ"

#include "hms_table_type.typ"


== Data Files <data_files>

In this subsection, we compare the use of storage formats in table formats. Table formats differ in what storage formats are supported (see @supported_storage_formats), what the maximum file size of a data file can be (see @file_sizes), what compression codec is used (see @supported_compression_codecs), and how splits of data files are generated (see @split_generation), among many other things like row group sizes, page sizes, encodings, and so on.

#include "storage_formats.typ"

#include "file_sizes.typ"

#include "compression.typ"

#include "file_statistics.typ"

#include "split_generation.typ"


== Optimizations <optimizations>

Since table formats are intended to be used in different environments (e.g., a variety of open-source and closed-source query engines), many other things besides the metadata format need to be considered. The specifications of the table formats are typically quite short, mainly because issues related to file management and maintenance are out of scope.

Some table formats provide optimization procedures (e.g., the Iceberg `rewrite_` suite), and some delegate this work to execution engines that can handle it in a format-independent manner (e.g., statistics generation, the `optimize` procedure in Trino).

In this subsection, we compare support for table maintenance in @table_maintenance, statistics in @table_statistics, indexing in @indexing, caching in @caching, and data layout optimizations in @data_layout.

#include "table_maintenance.typ"

#include "table_statistics.typ"

#include "indexing.typ"

#include "caching.typ"

#include "layout.typ"
