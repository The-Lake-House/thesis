=== `CREATE TABLE` Semantics <section_create_table_semantics>

In this subsection, we look into at what files are created when a table is created. The code for this and future analyses is available on GitHub at https://github.com/The-Lake-House/dml.

==== Hive

No files are added to the base directory when a table is created. All table metadata is stored in the Hive Metastore (HMS).

==== Hudi

`.hoodie/hoodie.properties` is created, but no `commit` files are created.

==== Iceberg

A table metadata file is created that contains no snapshots.

==== Delta

A new Delta file is created with the `protocol`, `metaData`, and (optionally) `commitInfo` actions.

==== Conclusions

Some table formats create snapshots for table creation, some do not.
