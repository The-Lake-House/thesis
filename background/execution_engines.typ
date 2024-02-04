== Execution Engines <section_execution_engines>

There is a rich and long history of attempts to build query engines that provide a SQL-like language for expressing ad-hoc queries on top of general-purpose compute engines such as Apache Hadoop @ApacheHadoop and Spark @ApacheSpark @zahariaApacheSparkUnified2016.

Apache Hadoop is an open source implementation of MapReduce @deanMapReduceSimplifiedData2004. As discussed in @section_storage_systems, MapReduce is based on a shared-nothing architecture that exploits data locality for low-latency disk operations and fault tolerance by partitioning data across nodes using a file system called HDFS. Apache Hive was one of the first systems to compile SQL-like statements into a series of MapReduce jobs @thusooHiveWarehousingSolution2009. As more people joined the Hadoop ecosystem, the two-phase MapReduce model became too limiting @camacho-rodriguezApacheHiveMapReduce2019. Hadoop eventually moved to YARN @vavilapalliApacheHadoopYARN2013, a runtime manager that allows data to be processed as complex directed acyclic graphs (DAGs). MapReduce became a special case of Hadoop, and many other frameworks, including Spark @zahariaApacheSparkUnified2016, were able to use the data stored in HDFS in new ways. Apache Hive and many other SQL-on-Hadoop solutions such as Impala @kornackerImpalaModernOpensource2015 and Apache Drill @hausenblasApacheDrillInteractive2013 followed. Spark had a similar history: first there were systems like Shark that translated SQL statements into Spark jobs @xinSharkSQLRich2013, and later Spark SQL was embedded in Spark @armbrustSparkSQLRelational2015.

As data sizes grew, there was a need for disaggregated storage for independent scalability of processing and storage. Data was moved to the cloud, and new processing platforms such as BigQuery @melnikDremelInteractiveAnalysis2010, Presto @Presto @sethiPrestoSQLEverything2019 and Snowflake @dagevilleSnowflakeElasticData2016 @vuppalapatiBuildingElasticQuery2020 based on shared-storage were created @tanChoosingCloudDBMS2019.

In this thesis, we will mainly focus on Spark and Trino, a fork of Presto. Spark is designed for ETL tasks, while Trino is designed for ad-hoc queries @RearchitectingTrinoDevelopment. ETL tasks take longer and have a higher error rate, so they require a higher level of fault tolerance.


=== Apache Spark

Apache Spark @ApacheSpark is a data analysis environment that also supports SQL queries @zahariaApacheSparkUnified2016 written in Scala and developed by Databricks. The code is available as open source @ApacheSpark2024, but there is also a commercial offering called the Databricks Runtime (DBR), which is a customized version of the Spark runtime with additional features and optimizations @armbrustDeltaLakeHighperformance2020.

There are many interfaces to Spark: `spark-shell` is an interactive Scala interpreter, `spark-sql` is an interactive SQL interpreter, and `spark-submit` is a tool for submitting jobs to a Spark cluster. `pyspark` is a Python frontend, similar to `spark-shell`.

The main abstraction of Spark are _Resilient Distributed Datasets_ (RDDs) @zahariaResilientDistributedDatasets2012, a distributed memory abstraction that allows programmers to perform in-memory computations on large clusters while preserving the fault tolerance of data flow models such as MapReduce. While programming with RDDs is low-level and imperative, SQL, DataFrames, and Datasets provide more modern, structured, and declarative APIs. These APIs were introduced in Spark 1.0.0 @SparkRelease100, Spark 1.3.0 @SparkRelease130, and Spark 1.6.0 @SparkRelease160, respectively.

The structured APIs also result in faster code through the Catalyst optimizer, which supports both rule-based and cost-based optimization @armbrustSparkSQLRelational2015. Spark 3.0.0 introduced Adaptive Query Execution (AQE) to dynamically update query plans during execution @SparkRelease300. One notable difference between Trino and Spark is that Spark's cost-based optimizer (CBO) is disabled by default. It can be enabled with `--conf spark.sql.cbo.enabled=true`.

Spark can run in standalone mode, but also supports various cluster management tools such as YARN, Kubernetes, or the now deprecated Apache Mesos @SparkMesos.

Support for table formats requires the use of plugins, as shown in @setup. No table format other than Hive is natively supported by Spark.

Spark has historically focused on a single catalog that is supported by an embedded version of the Hive Metastore by default @SPARK13477UserfacingCatalog. Therefore, each plugin provides its own extension of the default catalog so that its own tables can be handled by the plugin and the remaining tables can be delegated to Hive. This creates conflicts when multiple plugins are used at the same time. Spark 3.0.0 introduced support for multiple catalogs which should resolve these conflicts @SparkRelease300, but not all table formats support multiple catalogs yet @ApacheHudiGitHube.

Despite the problems with setting up multiple table formats, Spark is generally the most feature-rich environment, so we did many of our experiments in Spark.

Spark can be configured using the `spark-defaults.conf` file in `$SPARK_HOME/conf`, or by passing `--conf name=value` parameters to the command-line programs.


=== Apache Trino <trino>

Presto, originally called PrestoDB, came out of Facebook in 2013 as the successor to Hive @RearchitectingTrinoDevelopment. It was released under an open source license, and its development is overseen by the Linux Foundation. The original developers left Facebook in 2018 after a dispute with management and continued to work on a fork of the project called PrestoSQL, which was later renamed to Trino @TrinoBlogWe and is now overseen by the Trino Foundation. The choice of Trino over Presto for this thesis is more or less incidental#footnote[Truth be told, it's because of Commander Bun Bun, Trino's mascot :-)].

Trino is not a database because it has no storage component and everything is in-memory. Data retrieval is federated. There are many connectors to connect Trino to various data sources such as other relational databases (e.g., MySQL, PostgreSQL), NoSQL databases (e.g., MongoDB, Redis), common benchmarks whose tables are generated on the fly using a deterministic algorithm (e.g., TPC-H, TPC-DS), system metadata, in-memory tables, or finally, table-based formats on HDFS or in object stores. Trino natively supports the Apache Hive, Apache Hive ACID, Apache Hudi, Apache Iceberg, and Delta Lake table formats. While it is possible to add custom plugins into an existing Trino installation @TrinoCustomPlugin, support for all table formats is already included in the main distribution and no additional plugins need to be installed.

Since Trino does not have a persistence layer, it uses a catalog to find tables. Unlike Spark, Trino relies on an external catalog, supporting either the Hive Metastore (`hive.metastore=thrift`) or AWS Glue (`hive.metastore=glue`). In some cases, such as Iceberg, additional catalog types are supported, such as RESTful implementations @IcebergCatalogs. If the Hive Metastore is selected as the catalog, the URI of its Thrift API endpoint must be configured using the `hive.metastore.uri` parameter.

For a distributed system, Trino has only a few components (see @figure_architecture_trino). There is a single coordinator node that accepts, parses, analyzes, and optimizes SQL query strings via a command-line tool or JDBC, and then distributes fragments to worker nodes that perform query tasks and possibly access the data sources. The worker nodes connect to the coordinator through a discovery service.

#figure(
  image("/_img/trino_architecture.svg"),
  caption: [Architecture of Trino],
) <figure_architecture_trino>

Trino is a query engine based on a massively-parallel processing (MPP) architecture where a query is split into multiple stages, and each stage has multiple interconnected tasks @RearchitectingTrinoDevelopment. This results in fast, low-latency, and pipelined operations, but also means that if one task fails, the entire query fails, which can happen once the memory wall is hit @RearchitectingTrinoDevelopment because spillover to disk is disabled by default @TrinoDocumentationSpill. The coordinator is a single point of failure. The system is therefore not particularly robust, but efforts are being made to address these issues, e.g., by putting the entire system on Spark for fault tolerance @sunPrestoDecadeSQL2023.

Trino has a cost-based-optimizer (CBO) enabled by default, and each table format is configured to collect table statistics and use them during query planning.

An instance of a connector is, confusingly, also called a catalog. A connector can be instantiated by creating a file `name.properties` in `$TRINO_HOME/etc/catalog`, after which it can be referenced in Trino by `name`. Each connector properties file has at least a `connector.name` property describing which connector to use, and connector-specific configuration properties.

There are two ways to configure connectors: configuration parameters and session parameters. Configuration parameters are typically set in the catalog file. The Trino server must be restarted for a change to take effect. Session parameters on the other hand can be changed at any time using `SET SESSION catalog.name=value;`. All session parameters and their current values can be printed using `SHOW SESSION;`.

Note that some session parameters are hidden and do not appear in the listing. These can only be found by examining the source code, e.g., by looking at the `DeltaLakeSessionProperties.java` file of the Delta Lake connector @TrinodbTrinoGitHubi.

Not all connector configuration properties have corresponding session properties, so side effects can creep in. A good way to handle different configurations that do not allow session parameters is to create catalogs with different names that use the same connectors.
