== Storage Systems <section_storage_systems>

The history of the lakehouse is intertwined with both traditional big data processing frameworks such as Apache Hadoop @ApacheHadoop, based on the MapReduce paradigm @deanMapReduceSimplifiedData2004, and cloud computing solutions. Therefore, the main storage systems used in lakehouse architectures are the Hadoop Distributed File System (HDFS) @HadoopHDFS, an implementation of Google's GPFS @ghemawatGoogleFileSystem2003, and cloud storage, especially cloud object storage.

HDFS and cloud storage are fundamentally different: HDFS is a collocated storage system, and cloud storage is a disaggregated storage system. HDFS follows a shared-nothing architecture, where data processing and data storage are performed on the same node by partitioning persistent data across a set of compute nodes (hence _collocated_), enabling high-performance and scalable processing of very large datasets @vuppalapatiBuildingElasticQuery2020.

In practice, however, this architecture suffers from a hardware-workload mismatch and a lack of elasticity @vuppalapatiBuildingElasticQuery2020. Hardware is optimized for either processing or storage, and scaling one means scaling the other. In a disaggregated system, processing and storage are separated, and each component can scale independently.

Abandoning the data locality optimization of Hadoop and HDFS and embracing the cloud computing approach means accepting high latency as each data request is turned into a TCP/IP request. However, through a combination of high bandwidth, reducing the distance between processing and storage nodes, and clever techniques @melnikDremelDecadeInteractive2020 @sunPrestoDecadeSQL2023 the overhead becomes manageable.

File operations in both HDFS and cloud object storage are limited compared to the POSIX API, the biggest difference being that there are no real directories and that files are immutable or can only be appended to or replaced by another file. While this makes writing data expensive, the high cost also provides opportunities to write data in column-oriented formats with added statistics, etc.

Most query engines are built on top of Apache Hadoop or depend on it in some way and handle file system operations through HDFS. HDFS supports storage on Amazon S3, Azure Data Lake Storage (ADLS), and Google Cloud Storage (GCS) through its filesystem API @HadoopFilesystemAPI. Support for Amazon S3 on top of the filesystem API is provided by Hadoop-AWS @HadoopAWS. The filesystem API supports the following protocols: `hdfs://` for HDFS, `s3a://` for S3-compatible cloud object storage, and `file://` for POSIX-compatible storage. Older S3-compatible protocols such as `s3://` and `s3n://` represent previous generations of `s3a://` and have been deprecated and removed.

Object stores provide various consistency guarantees: some are only eventually consistent. This can lead to problems such as writing an object, but the object not showing up in a file listing immediately afterwards.

Using object stores instead of HDFS is controversial; for example, Spark actively discourages the use of object stores due to the lack of real directories, their consistency issues, and slow seeks @SparkCloudIntegration.


=== Amazon S3

Amazon S3 @AmazonS3 has been available since March 2006 @AWSNewsBlog2006. It is essentially a cloud-based key-value store. Key-value pairs are stored in buckets. Key names can be arbitrary strings, limited to 1,024 bytes @S3Prefixes. There is no namespacing, but '`/`' can be used as a delimiter to emulate directories. Key-value pairs are immutable, as discussed earlier.

Amazon S3 has a RESTful API that allows to make a bucket, delete a bucket, list objects in a bucket, get the metadata of an object in a bucket, get an entire object from a bucket, get a region of an object from a bucket, add an object to a bucket, replace an object in a bucket, delete an object in a bucket, and many more operations @S3RESTAPI. Especially relevant for this thesis are `GetObject` @S3GetObject to get an entire or partial object from a bucket, `HeadObject` @S3HeadObject to get the metadata of an object, and `ListObjectsV2` @S3ListObjectsV2 to list objects in a bucket.

Amazon S3 used to be eventually consistent, but as of December 2020 it is strongly consistent for LIST, GET, and PUT operations @AWSNewsBlog2020. It still lacks support for atomic renames and _put if absent_ operations, requiring workarounds by for example Delta Lake @armbrustDeltaLakeHighperformance2020.


=== S3-Compatible Systems

The S3 API is the de facto standard for object storage, and many commercial cloud storage systems like Azure Blob Storage @AzureBlobStorage and Google Cloud Storage @GoogleCloudStorage implement it. There are also some open source solutions that can be deployed on-premises, such as MinIO @MinIO, Ceph @CephIo, and SeaweedFS @SeaweedFSArchitecture2021. We used MinIO for all of our experiments because it has a _Single Disk, Single Node_ (SDSN) mode, which makes it a good choice for prototyping the S3 API because it is easy to set up (see @setup).
