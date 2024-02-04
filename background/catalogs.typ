#import "/flex-caption.typ" as flex

=== Catalogs <section_catalogs>

A catalog is a central service that contains an inventory of schemas and tables available in the storage system. Typically, catalogs are embedded in a relational database management system (RDBMS), but in modern architectures they are external because a) query engines such as Trino do not have a storage layer, and b) the underlying storage system may contain more than tables or may not have a table abstraction (e.g., in a data lake).

The Hive Metastore (HMS) @thusooHiveWarehousingSolution2009 is the de-facto standard for catalogs. It is a component of and bundled with Apache Hive, but due to its wide adoption, it is now also available as a standalone version @HIVE17168CreateSeparate.

Hive uses it for all of its metadata, including table definitions, columns definitions, partitioning column definitions, bucketing column definitions, statistics, governance, and so on, which explains the complexity of the schema in @figure_hms_schema. With Hive 3.0, the schema has become even more complex, including, for example, transaction management for Hive ACID @camacho-rodriguezApacheHiveMapReduce2019. Execution engines such as Spark and Trino use only a small fraction of the functionality of the Hive Metastore when working with table formats such as Hudi, Iceberg, and Delta Lake because most of the metadata is stored along with the tables. The only HMS tables that matter are `DBS` and `DATABASE_PARAMS` to manage schemas, and `TBLS` and `TABLE_PARAMS` to manage tables.

#figure(
  image("/_img/hms.svg"),
  caption: flex.flex-caption(
    [Schema of the Hive (2.x) Metastore @ApacheHiveAdminManual],
    [Schema of the Hive (2.x) Metastore],
  ),
) <figure_hms_schema>

The metastore service API is available by default on port 9093. It is a Thrift API @ApacheThrift that can be queried, for example, using the `pymetastore` Python library @RecapbuildPymetastore2023.

HMS supports a variety of RDBMSes such as MySQL, PostgreSQL, and SQLite through the JPOX ORM (Data Nucleus) @ApacheHiveAdminManual to persist its data. By default, it uses a Derby database in embedded mode and persists the data in the directory from which the HMS was started. However, in embedded mode, the Derby instance only allows one connection at a time, which is insufficient for most lakehouse formats, which require a separate connection to extract and persist metadata in addition to the query engine used (Iceberg uses the HMS for locking). Instead of running Derby in server mode, a regular RDBMS can be used. HMS has the ability to generate the required schema automatically (if `datanucleus.schema.autoCreateAll` is set in `hive-site.xml`), or manually using `schematool` bundled with Hive, which in our experience works better.

Apache Spark bundles Hive and uses it in embedded mode by default.

There are several alternatives to the HMS, including AWS Glue @AWSGlue, Nessie @ProjectNessie, and Unity Catalog @DatabricksUnityCatalog. HMS is probably predominant because most lakehouse components started out as Apache Hive successors.
