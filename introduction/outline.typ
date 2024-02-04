== Outline

In this thesis we attempt to answer the question of how lakehouse table formats differ in metadata structure and features, and what impact these differences have on their performance.

We analyze Apache Hudi, Apache Iceberg, and Delta Lake, using the Apache Hive table format as a prior art reference. The comparison is done conceptually, the evaluation is done with benchmarks and load tests.

The thesis is structured as follows:

+ *Background*: This chapter describes the components of a lakehouse architecture.

+ *Comparison*: This chapter compares lakehouse table formats on key criteria such as metadata management, use of storage files, and performance optimizations.

+ *Evaluation*: In this chapter, we evaluate lakehouse table formats on the query runtimes of a TPC-H query in Trino and on their scalability patterns for change operations in Spark. We address issues of comparability, differences between execution engines, and possible mitigations for the problems we identify. We also investigate the ideal size of Parquet files and the split size for concurrent processing.

+ *Conclusion*: This chapter serves as both a conclusion to the thesis and an evaluation of the topics discussed.
