= Supplemental Data

All data and code is available on GitHub at https://github.com/The-Lake-House. The storage device attached to the physical copy of this thesis contains a copy of all the GitHub repositories listed below, as well as the weekly slide decks and the raw and PDF versions of this document.

The #link("https://github.com/The-Lake-House/dml")[`dml`] repository contains the code and data used to compare the metadata management of table formats in @metadata_management.

The #link("https://github.com/The-Lake-House/scan_planner")[`scan_planner`] repository contains the reimplementation of scan planning for Hive, Hudi, Iceberg, and Delta Lake described in @read_path.

The #link("https://github.com/The-Lake-House/tpch")[`tpch`] repository contains the code, data, and plots of the TPC-H benchmark described in @tpch_benchmark.

The #link("https://github.com/The-Lake-House/many_ops")[`many_ops`] repository contains the code, data, and plots used for the _Many Inserts_, _Many Deletes_, _Many Updates_, and _Many Inserts (Partitioned)_ analyses described in @scalability_table_formats and @request_types.

The #link("https://github.com/The-Lake-House/hudi_hmt")[`hudi_hmt`], #link("https://github.com/The-Lake-House/iceberg_rewrite_position_delete_files")[`iceberg_rewrite_position_delete_files`], and #link("https://github.com/The-Lake-House/delta_checkpointing")[`delta_checkpointing`] repositories contain the code, data, and plots used to test the mitigations in @hudi_file_caching, @iceberg_rewrite_position_delete_files, and @delta_checkpointing, respectively.

The #link("https://github.com/The-Lake-House/get_object")[`get_object`] and #link("https://github.com/The-Lake-House/list_objects")[`list_objects`] repositories contain the code, data, and plots used to load test MinIO in @scalability_object_storage.

The #link("https://github.com/The-Lake-House/ideal_parquet_size")[`ideal_parquet_size`] repository contains the code, data, and plots used to determine the ideal size of a Parquet file in @parquet_size_determination.

The #link("https://github.com/The-Lake-House/thesis")[`thesis`] repository contains the code, images, and PDF version of this document.

Small tools are listed in @tools.
