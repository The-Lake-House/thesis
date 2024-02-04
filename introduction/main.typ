= Introduction <introduction>

The lakehouse is an emerging data architecture that combines the structure and management features of data lakes with the scalability and flexibility of data lakes @armbrustLakehouseNewGeneration2021.

A data warehouse is a database that combines data from different operational databases (such as relational database management systems) for decision support @chaudhuriOverviewDataWarehousing1997. While operational databases are designed to process a few gigabytes or terabytes of transactional data (called online transactional processing, or OLTP), data warehouses are optimized for aggregating large data sets in the terabytes to petabytes range (called online analytical processing, or OLAP). Changes to a data warehouse are ingested using either batch or stream processing. Batching is a periodic process that extracts, transforms, and loads data from multiple data sources into the data warehouse, a process commonly referred to as ETL (Extract, Transform, Load). Alternatively, data can be ingested on an element-by-element basis using streaming.

This architecture has been deployed successfully for many decades, but it has a number of shortcomings, including staleness, reliability, cost, lock-in effects, and limited use cases @armbrustLakehouseNewGeneration2021. Data is stored in multiple places at once, leading to outdated data, unreliable ETL processes, operational and licensing costs, and potential lock-in effects if a proprietary data warehousing solution is chosen. Data in a data warehouse is accessed through SQL and is not readily accessible in raw format without exports for analysis in data science and machine learning tools.

As the volume, variety, and velocity of data has increased, data lakes have become the most common data management solution in Fortune 500 companies @armbrustLakehouseNewGeneration2021. A data lake is a massive repository of data that includes structured, semi-structured, and unstructured data @fangManagingDataLakes2015. Because of their size, data lakes are often stored in inexpensive cloud storage.

Data lakes allow diverse workloads to run on the same copy of the data: Multiple execution engines can access the open data files in storage in a no-copy, in-situ, schema-on-read fashion @mazumdarDataLakehouseData2023. The separation of storage and compute scales with the demands of big data.

However, data lakes typically do not allow file modification and offer poor consistency guarantees. In addition, without additional infrastructure, there are no optimizations on the files in a data lake, such as indexes. For these reasons, it is often necessary to combine both data warehouses and data lakes using a two-tier architecture, where the data warehouse is fed with data from the data lake, adding complexity and cost.

Armbrust et al. argue in their paper "Lakehouse: a new generation of open platforms that unify data warehousing and advanced analytics" @armbrustLakehouseNewGeneration2021 that lakehouses will gradually replace traditional data warehouses. They define the lakehouse "as a data management system based on low-cost and directly-accessible storage that also provides traditional analytical DBMS management and performance features such as ACID transactions, data versioning, auditing, indexing, caching, and query optimization." It combines the cost-effective storage and access to semi-structured and unstructured data of data lakes with the mutability of data warehouses without the added overhead of a two-tier architecture.

Mutability is achieved using a metadata layer on top of the data files within the data lake. The metadata layer logically groups data files into a table that can be queried and modified, much like a table in a relational database or a data frame in a data science environment. Changes are captured like a write-ahead log, with each entry embedding additional metadata such as zone maps and Bloom filters for improved performance. In addition to ACID transactions, this log-based structure enables additional features such as versioning, schema evolution, time travel (i.e., going back to previous snapshots of the table), and auditability.

To replace data warehouses, these lakehouse table formats must support both ingestion mechanisms (batch and stream), have optimization capabilities, and have open specifications so that they can be easily implemented by execution engines.

The ETL processes found in data warehousing can then be simplified into refinement processes that take place in the same storage system using the same execution engines used for querying. As a result, data is always up to date.

Performance can also be improved by changing the data layout of data files, such as partitioning tuples with similar attribute values or sorting by attribute value for better compression.

Metadata is stored with the data files in the same storage system to reduce reliance on additional infrastructure. Eliminating centralized coordination services presents challenges for transaction management, particularly isolation and concurrency, and data governance. However, the simplified architecture results in lower costs, broad use case support, and no lock-in effects.

The data can be accessed via SQL and DataFrame APIs, supporting business intelligence (BI) and reporting as well as machine learning and data science use cases. In fact, lakehouses have been deployed in domains such as biomedical research @begoliLakehouseArchitectureManagement2021, IoT @liuIoTLakehouseNew2023, and deep learning @hambardzumyanDeepLakeLakehouse2022.

In addition to typical data warehousing and data lake use cases, lakehouses enable GDPR (_General Data Protection Regulation_) and CCPA (_California Consumer Privacy Act_) compliance for very large datasets @sunPrestoDecadeSQL2023.

#include "outline.typ"

#include "related_works.typ"
