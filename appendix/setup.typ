= Setup <setup>

The following are setup instructions for an on-premises Linux-based data lakehouse environment for testing purposes based on the Hive Metastore (HMS) as the catalog using PostgreSQL as its database, Apache Spark or Trino as the execution engines, and MinIO as the object store.

== Java

Install the OpenJDK Java 17 development kit via the package manager of your Linux distribution and set the `JAVA_HOME` environment variable accordingly.


== PostgreSQL

PostgreSQL is needed as a dependency for the HMS. PostgreSQL should be installed via the package manager of your Linux distribution and configured according to the manual of your Linux distribution.

Once installed, configured, and started, create a new user called `hms` using password `hms` using `createuser --pwprompt hms` and a new database called `hms` using `createdb --owner hms hms`.


== MinIO

For MinIO, both server and client are needed. They can be installed using the package manager of your Linux distribution or by downloading the binary releases available on the MinIO website.

After installing and starting the server components, visit http://127.0.0.1:9000, sign in with the default credentials (`minioadmin` and `minioadmin`), and create access keys (`Access Keys` --> `Create access key`).

Set the `AWS_ENDPOINT_URL`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` environment variables, which are understood by many other S3-compatible tools:

```bash
export AWS_ENDPOINT_URL='http://127.0.0.1:9000'
export AWS_ACCESS_KEY_ID='ACCESSKEY'
export AWS_SECRET_ACCESS_KEY='SECRETKEY'
```

The client can then be configured using `mcli alias set minio $AWS_ENDPOINT_URL $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY`.

Note that without specifying the alias, `mcli` can also act as a POSIX-compatible file manager, i.e., `mcli ls` will list the files in the current directory, `mcli rm` will remove them.

The original name of the MinIO client is `mc`, but some Linux distributions decided to rename `mc` to `mcli` so as not to conflict with the popular Midnight Commander (`mc`).

Since MinIO is compatible with S3, there are many other clients to choose from. An alternative to the `mcli` tool mentioned above is `s3cmd` @s3cmd. To configure `s3cmd`, create a file named `.s3cfg` in your home directory with the following contents:

```
host_base = 127.0.0.1:9000
host_bucket = 127.0.0.1:9000
use_https = False
access_key = ACCESSKEY
secret_key = SECRETKEY
```

The S3 API is active on port 9000, but when visited by a browser, it is redirected to an administrative web interface.


== Apache Hadoop

Apache Hadoop is a dependency of certain components of Apache Hive, Apache Spark, and Trino. At the time of writing Apache Hadoop 3.3.2 provided the broadest compatibility between query engines and lakehouse table formats.

+ Download Hadoop: `wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.2/hadoop-3.3.2.tar.gz`
+ Extract compressed tarball: `tar xzf hadoop-3.3.2.tar.gz`
+ Set the environment variable `HADOOP_HOME` to the extracted directory


== Apache Hive

+ Download Apache Hive: `wget https://archive.apache.org/dist/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz`
+ Extract compressed tarball: `tar xzf apache-hive-3.1.3-bin.tar.gz`
+ Set the environment variable `HIVE_HOME` to the extracted directory
+ Symlink the S3 dependencies that are distributed with Hadoop: `ln -s $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-bundle-1.11.1026.jar $HIVE_HOME/lib/aws-java-sdk-bundle.jar` and `ln -s $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-3.3.2.jar $HIVE_HOME/lib/hadoop-aws.jar`
+ Create a warehouse directory at a location of your choice and set the `WAREHOUSE_DIR` environment variable to it
+ Create `$HIVE_HOME/conf/hive-site.xml` according to the following template and set `WAREHOUSE_DIR`, `AWS_ENDPOINT_URL`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` to the values of the corresponding environment variables:

  ```xml
  <configuration>
    <!-- Warehouse -->
    <property>
      <name>hive.metastore.warehouse.dir</name>
      <value>WAREHOUSE_DIR</value>
    </property>
    <!-- PostgreSQL -->
    <property>
      <name>javax.jdo.option.ConnectionURL</name>
      <value>jdbc:postgresql://127.0.0.1/hms</value>
    </property>
    <property>
      <name>javax.jdo.option.ConnectionDriverName</name>
      <value>org.postgresql.Driver</value>
    </property>
    <property>
      <name>javax.jdo.option.ConnectionUserName</name>
      <value>hms</value>
    </property>
    <property>
      <name>javax.jdo.option.ConnectionPassword</name>
      <value>hms</value>
    </property>
    <!-- MinIO -->
    <property>
      <name>fs.s3a.endpoint</name>
      <value>AWS_ENDPOINT_URL</value>
    </property>
    <property>
      <name>fs.s3a.access.key</name>
      <value>AWS_ACCESS_KEY_ID</value>
    </property>
    <property>
      <name>fs.s3a.secret.key</name>
      <value>AWS_SECRET_ACCESS_KEY</value>
    </property>
    <property>
      <name>fs.s3a.connection.ssl.enabled</name>
      <value>false</value>
    </property>
    <property>
      <name>fs.s3a.path.style.access</name>
      <value>true</value>
    </property>
  </configuration>
  ```

+ Initialize the database schema: `$HIVE_HOME/bin/schematool --dbType postgres --initSchema`
+ Start the HMS: `$HIVE_HOME/bin/hive --service metastore`


== Trino

Install Trino according to https://trino.io/docs/current/installation/deployment.html. Here we focus on a single node system where one node is both coordinator and worker. Setting `task.max-writer-count=1` will produce only a single output file (assuming the file is not large enough to roll over, see @file_sizes), which simplifies usage.

+ Download Trino: `wget https://repo1.maven.org/maven2/io/trino/trino-server/433/trino-server-433.tar.gz`
+ Extract compressed tarball: `tar xzf trino-server-433.tar.gz`
+ Set the environment variable `TRINO_HOME` to the extracted directory
+ Create the directory `$TRINO_HOME/etc` and add the following files

  + `config.properties`:

    ```properties
    # Single-node cluster
    coordinator=true
    node-scheduler.include-coordinator=true
    http-server.http.port=8080
    http-server.log.enabled=false
    discovery.uri=http://localhost:8080
    ```

  + `jvm.config`: set `-Xmx` to 75 to 80% of the total available memory.

    ```
    -server
    -Xmx8G
    -XX:InitialRAMPercentage=80
    -XX:MaxRAMPercentage=80
    -XX:G1HeapRegionSize=32M
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+ExitOnOutOfMemoryError
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:-OmitStackTraceInFastThrow
    -XX:ReservedCodeCacheSize=512M
    -XX:PerMethodRecompilationCutoff=10000
    -XX:PerBytecodeRecompilationCutoff=10000
    -Djdk.attach.allowAttachSelf=true
    -Djdk.nio.maxCachedBufferSize=2000000
    -Dfile.encoding=UTF-8
    # Reduce starvation of threads by GClocker, recommend to set about the
    # number of cpu cores (JDK-8192647)
    -XX:+UnlockDiagnosticVMOptions
    -XX:GCLockerRetryAllocationCount=32
    ```

  + `node.properties`: set `node.data-dir` to some directory of your choice.

    ```properties
    node.environment=production
    node.id=trino
    node.data-dir=/var/trino/data
    ```

+ Start Trino server: `$TRINO_HOME/bin/launcher run`

Install the Trino Client according to https://trino.io/docs/current/client/cli.html:

+ Download Trino client: `curl -o $TRINO_HOME/bin/trino https://repo1.maven.org/maven2/io/trino/trino-cli/433/trino-cli-433-executable.jar`
+ Make binary executable: `chmod +x $TRINO_HOME/bin/trino`
+ Start Trino client: `$TRINO_HOME/bin/trino`

=== Connector Configuration

Connectors are used through catalogs. Each catalog can use only one connector. This allows, for example, multiple Iceberg connectors to be used with different settings. For each connector, the metastore URI and S3 connection details must be configured. Property files in Trino allow expansion using environment variables with the following syntax: `${ENV:VAR_NAME}`.

==== Hive

Hive is less permissive than other table formats: certain DDL statements such as `DROP TABLE` must be explicitly enabled. Also, writing to external tables is disabled by default.

`$TRINO_HOME/etc/catalog/hive.properties`:

```properties
connector.name=hive
hive.metastore.uri=thrift://localhost:9083

hive.allow-drop-table=true

# Allow writes to S3
hive.non-managed-table-writes-enabled=true

# S3
hive.s3.endpoint=${ENV:AWS_ENDPOINT_URL}
hive.s3.aws-access-key=${ENV:AWS_ACCESS_KEY_ID}
hive.s3.aws-secret-key=${ENV:AWS_SECRET_ACCESS_KEY}
hive.s3.ssl.enabled=false
hive.s3.path-style-access=true
```

`non-managed-table-writes-enabled=true` allows writing to external tables.


==== Hudi

Note that the Hudi connector is currently read-only: DDL and DML statements that write to the table are not supported @TrinoDocumentationHudi.

`$TRINO_HOME/etc/catalog/hudi.properties`:

```properties
connector.name=hudi
hive.metastore.uri=thrift://localhost:9083

# S3
hive.s3.endpoint=${ENV:AWS_ENDPOINT_URL}
hive.s3.aws-access-key=${ENV:AWS_ACCESS_KEY_ID}
hive.s3.aws-secret-key=${ENV:AWS_SECRET_ACCESS_KEY}
hive.s3.ssl.enabled=false
hive.s3.path-style-access=true
```


==== Iceberg

`$TRINO_HOME/etc/catalog/iceberg.properties`:

```properties
connector.name=iceberg
iceberg.catalog.type=hive_metastore
hive.metastore.uri=thrift://localhost:9083

# Do not write to a unique location
iceberg.unique-table-location=false

# S3
hive.s3.endpoint=${ENV:AWS_ENDPOINT_URL}
hive.s3.aws-access-key=${ENV:AWS_ACCESS_KEY_ID}
hive.s3.aws-secret-key=${ENV:AWS_SECRET_ACCESS_KEY}
hive.s3.ssl.enabled=false
hive.s3.path-style-access=true
```

`unique-table-location=false` prevents a random postfix to be added to the table name.

==== Delta Lake

`$TRINO_HOME/etc/catalog/delta.properties`:

```properties
connector.name=delta_lake
hive.metastore.uri=thrift://localhost:9083

# Do not write to a unique location
delta.unique-table-location=false

# Allow writes to S3
delta.enable-non-concurrent-writes=true

# S3
hive.s3.endpoint=${ENV:AWS_ENDPOINT_URL}
hive.s3.aws-access-key=${ENV:AWS_ACCESS_KEY_ID}
hive.s3.aws-secret-key=${ENV:AWS_SECRET_ACCESS_KEY}
hive.s3.ssl.enabled=false
hive.s3.path-style-access=true
```

`unique-table-location=false` prevents a random postfix to be added to the table name.

`enable-non-concurrent-writes=true` enables write support to S3 or S3-compatible storage by acknowledging the risk of write collisions.


==== TPC-H <setup_tpch>

`$TRINO_HOME/etc/catalog/tpch.properties`:

```properties
connector.name=tpch
tpch.column-naming=STANDARD
```

In the TPC-H specification, each column name is prefixed with a per-table prefix @TPCH, e.g., the prefix for the `lineitem` table is `l_`. The Trino `tpch` connector omits these prefixes by default, but they can be added by setting `tpch.column-naming=STANDARD` in the catalog configuration file. This way, the queries in the TPC-H standard do not need to be modified.

=== Schema and Table Creation

A location can be specified with a schema. If set, tables will be created at the specified location, otherwise they will be created in the warehouse directory. S3 locations can be specified using the `s3a://` protocol. Support for this protocol was previously provided by Hadoop (concretely, the Hadoop File System API @HadoopFilesystemAPI), but is more and more ported over to Trino with the goal to eventually eliminate the dependency on Hadoop @TrinodbTrinoGitHubf.

```sql
CREATE SCHEMA IF NOT EXISTS hive.tpch_hive WITH (location = 's3a://tpch/hive');
```

A catalog in Trino can only be associated with a single connector. Therefore, it is clear what table format to read or write once the catalog name is specified.

```sql
CREATE TABLE iceberg.tpch_iceberg.lineitem AS SELECT * FROM tpch.sf1.lineitem;
```


== Apache Spark

For Spark, an immutable configuration approach was chosen for better reproducibility and to better adapt to different versions of Spark. This is problematic when PySpark, sparkR, and Scala Spark need to be used together because they all need to be configured separately.

+ Download Spark: `wget https://archive.apache.org/dist/spark/spark-3.4.2/spark-3.4.2-bin-hadoop3.tgz`
+ Extract compressed tarball: `tar xzf spark-3.4.2-bin-hadoop3.tgz`
+ Set the environment variable `SPARK_HOME` to the extracted directory
+ Configure the amount of memory the Spark driver may use (this defaults to a measly 1 GB): set `--driver-memory Xg` to 75 to 80% of the total available memory with every invocation of `spark-sql` or `spark-shell`
+ Configure the connection to the HMS: provide `--conf spark.hadoop.hive.metastore.uris=thrift://localhost:9083` with every invocation of `spark-sql` or `spark-shell`
+ Configue S3: provide 
  ```bash
  --conf spark.hadoop.fs.s3a.endpoint=$AWS_ENDPOINT_URL
  --conf spark.hadoop.fs.s3a.access.key=$AWS_ACCESS_KEY_ID
  --conf spark.hadoop.fs.s3a.secret.key=$AWS_SECRET_ACCESS_KEY
  --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.\
         S3AFileSystem
  --conf spark.hadoop.fs.s3a.bucket.probe=0 
  --conf spark.hadoop.fs.s3a.connection.maximum=250
  --jars $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-3.3.2.jar,\
         $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-\
         bundle-1.11.1026.jar
  ```
  with every invocation of `spark-sql` or `spark-shell`

Options passed with a `spark.hadoop` prefix are passed to Hadoop. `fs.s3a.bucket.probe` is an optimization that skips bucket probes @HadoopS3A. In our case `fs.s3a.connection.maximum` needed to be increased from its default value of 96 @HadoopCoreDefault to handle MoR tables in Hudi consisting of ~100 log files, otherwise `SELECT` statements would hang indefinitely.

SQL statements can be issued directly in `$SPARK_HOME/bin/spark-sql`, or by wrapping them in `spark.sql(query)` in `$SPARK_HOME/bin/spark-shell` or `$SPARK_HOME/bin/pyspark`.

Support for table formats has to be added via plugins, and some plugins are not compatible with each other. Therefore, a distributed setup with multiple worker nodes was not pursued. Besides, `spark-submit`, the program used to submit jobs to a Spark cluster, requires whole programs (JARs in the Java context and Python scripts with bootstrapping in the Python context) to be submitted, making it cumbersome to use.


=== Table Format Plugins

==== Hive

Support for Hive tables is enabled by default.


==== Hudi

Provide the following arguments with every invocation of `spark-sql` or `spark-shell`:

```bash
--packages org.apache.hudi:hudi-spark3.4-bundle_2.12:0.14.0
--conf spark.serializer=org.apache.spark.serializer.KryoSerializer
--conf spark.sql.extensions=org.apache.spark.sql.hudi.\
       HoodieSparkSessionExtension
--conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.\
       catalog.HoodieCatalog
--conf spark.kryo.registrator=org.apache.spark.\
       HoodieSparkKryoRegistrar
```

Hudi tables can be created by adding `USING hudi` to the `CREATE TABLE` statement.


==== Iceberg

Provide the following arguments with every invocation of `spark-sql` or `spark-shell`:

```bash
--packages org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3
--conf spark.sql.extensions=org.apache.iceberg.spark.extensions.\
       IcebergSparkSessionExtensions
--conf spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.\
       SparkSessionCatalog
```

Iceberg tables can be created by adding `USING iceberg` to the `CREATE TABLE` statement.


==== Delta Lake

Provide the following arguments with every invocation of `spark-sql` or `spark-shell`:

```bash
--packages io.delta:delta-core_2.12:2.4.0
--conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension
--conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.\
       catalog.DeltaCatalog
```

Delta Lake tables can be created by adding `USING delta` to the `CREATE TABLE` statement.
