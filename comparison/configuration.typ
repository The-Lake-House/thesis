=== Configuration

Given the openness, there needs to be a clear way to configure table formats. In general, this can be done by embedding the configuration directly in the table metadata.

There are three relevant types of configuration: table-specific, schema-wide, and system-wide configuration. Schema-wide and system-wide configuration typically depend on the execution environment.

Table-specific configuration is typically specified via the `TBLPROPERTIES` clause in Spark or the `WITH` clause in Trino in the `CREATE TABLE` statement. Spark also allows storage-specific configuration to be specified via the `OPTIONS` clause.

==== Hive

Table properties are stored in the Hive Metastore (HMS). Arbitrary key-value pairs can be stored, and there is no guarantee that execution engines will interpret them at all or correctly.

==== Hudi

Hudi has an overwhelming number of configuration options, and it is not clearly specified whether the options are table properties, data source properties, or internal properties. In Spark SQL, they can currently only be specified using an external config file or table properties @HUDI6730EnableHoodiea. The external configuration file is called `hudi-defaults.conf` and is located in `/etc/hudi/` by default, or as specified in the `HUDI_CONF_DIR` environment variable. Selected table properties are stored in `.hoodie/hoodie.properties` or in the Hive Metastore.

==== Iceberg

Selected table properties are stored in the `properties` field of the table metadata file.

==== Delta Lake

The table configuration is stored in the `configuration` field of a `metaData` action in Delta files. The most recent instance of the `metaData` action is used to accomodate changes in the configuration.

==== Conclusions

Table properties are a configuration mechanism common to all table formats. However, specifying table properties differs between Spark and Trino, and a list of all possible table properties and their default values is not always provided. Hudi is the only format that has global settings, and with the right location, cluster-wide configuration might be possible.
