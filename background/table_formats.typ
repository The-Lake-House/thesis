== Table Formats <section_table_formats>

Table formats provide the metadata layer on top of storage files necessary to achieve mutability, versioning, time travel, auditability, and query optimizations.

Commonly used table formats include Apache Hudi, Apache Iceberg, and Delta Lake. All of these table formats began development around the same time. Hudi has been in use at Uber since 2016 @chandarUberCaseIncremental2016, Iceberg was donated to Apache by Netflix in late 2017 @ApacheIcebergGitHub, and development of Delta Lake began at Databricks in 2016 @armbrustDeltaLakeHighperformance2020.

As an aside, Hudi is referred to as both Hudi and Hoodie. Hoodie was the name before it was adopted by Apache, and many references to that name still exist in the source code @ApacheHudiGitHubf.

Comparing and evaluating these table formats will be the subject of @comparison and @evaluation, hence the brevity.
