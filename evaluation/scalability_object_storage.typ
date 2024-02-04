#import "/flex-caption.typ" as flex

== Scalability of Object Storage <scalability_object_storage>

To estimate the amount of variability in the query runtime in @scalability_table_formats that is due to the object store rather than the table format, we ran two load tests in MinIO. They test the runtime performance of `GetObject` and `ListObjectsV2` with an increasing number of objects in a bucket. The load tests were done using MinIO Python @MinIOPythonQuickstart.

Occasionally, both `GetObject` and `ListObjectsV2` operations seemed to hang indefinitely once a certain number of objects were added to a bucket. In our experiments, this number was around 5,000. We could not find a reason for this behavior, and it persisted even after switching from the ext4 to the XFS filesystem recommended by MinIO. We observed the problem on the virtualized benchmark system, as well as on a 4-core desktop computer used for initial testing.

By default, the `Minio` client in Python has a timeout of 5 minutes with 5 retries and an exponential backoff factor @MinioMiniopyGitHub. To deal with the hangs, we had to pass a custom `urllib3.PoolManager` with a much shorter timeout of 5 seconds and 0 retries:

```python
import minio
import urllib3

client = minio.Minio(
    ENDPOINT,
    access_key=ACCESSKEY,
    secret_key=SECRETKEY,
    secure=False,
    http_client=urllib3.PoolManager(
        timeout=5.0,
        retries=False
    )
)
```

We considered requests that took more than 5 seconds to be outliers and removed them, otherwise the following analyses would not have been possible.


=== `GetObject` <minio_get_object>

In this analysis, we evaluate the scalability of `GetObject` by retrieving a random object from a bucket with an increasing number of objects in the bucket using the `get_object` call in MinIO Python.

Firing many `get_object` calls in rapid succession eventually resulted in a `Failed to establish a new connection: [Errno 99] Cannot assign requested address` error despite closing and releasing the connection. We worked around this problem by adding `time.sleep(0.1)` after each repetition to give the system time to reclaim resources.

#figure(
  image("/_img/minio/get_object.svg"),
  caption: flex.flex-caption(
    [Mean time of getting a random object using `GetObject` with an increasing number of objects. The blue line represents the linear regression fit computed using the lm (linear model) method. (n=25)],
    [MinIO: `GetObject` scalability],
  ),
) <minio_get_object_fig>

As we can see in @minio_get_object_fig, the performance of `GetObject` appears to be constant for the relatively small number of objects that we have tested.  The values are periodically clustered around two bounds, with the upper bound becoming more scattered as the number of objects increases. We assume that the upper bound is some kind of internal reorganization process that kicks in after a certain number of writes.

=== `ListObjectsV2` <minio_list_objects>

`ListObjectsV2` has a reputation for being a bottleneck @armbrustDeltaLakeHighperformance2020. In this analysis, we evaluate the scalability of `ListObjectsV2` by listing all objects in a bucket as the number of objects in the bucket increases, using the `list_objects` call in MinIO Python.

The S3 specification states that `ListObjectsV2` requests can only return up to 1,000 entries at a time (a soft limit can be specified with the `max-keys` URL parameter) @S3ListObjectsV2, a fact that the `list_objects` function transparently works around in single-threaded fashion @MinioMiniopyGitHuba. The listed objects are returned in ascending order by key name.

#figure(
  image("/_img/minio/list_objects.svg"),
  caption: flex.flex-caption(
    [Mean time of `ListObjectsV2` with an increasing number of objects with 95% confidence interval. The blue line represents the linear regression fit computed using the lm (linear model) method. (n=25)],
    [MinIO: `ListObjectsV2` scalability],
  ),
) <minio_list_objects_fig>

As we can see in @minio_list_objects_fig, the performance of `ListObjectsV2` appears to be mostly linear. After inserting about 5,000 objects and coinciding with the observation of hangups, there is a sudden increase in variability.  When performing the load tests in @scalability_table_formats in Trino, which allows for a much higher number of iterations due to the significantly lower startup overhead, this variability could be observed during query execution.  This variability did not show up in any of the system monitoring metrics; we assume it is either a bug in MinIO, or indeed a shortcoming of the file system or system architecture.


=== Conclusions

Extrapolating from the results in @scalability_table_formats, a single lakehouse table can easily contain tens of thousands of files, even if it is well maintained. In this experiment, we wanted to evaluate if MinIO had a potential impact on our measurement and if it could reliably scale to a large number of objects.

`GetObject` and `ListObjectsV2` run in $O(1)$ and $O(n)$, respectively, but as more objects are added to the bucket, the variability increases and hangups become more frequent. This is especially pronounced with `ListObjectsV2`, making load testing almost impossible without special handling of timeouts. This is particularly worrisome since the number of objects is not even as high as one would expect a cloud service to handle. S3 should not have these problems. For our analyses the impact should be acceptable because the total number of files is relatively small.

In a sense, the small files problem (see @file_sizes) is exacerbated in object stores because large file listings must be broken into chunks of 1,000, each requiring a high latency request. In practice, multiple requests are sent in parallel to achieve acceptable performance @armbrustDeltaLakeHighperformance2020.

In the next chapter, we examine the reliance of `GetObject` and `ListObjectsV2` in table formats.
