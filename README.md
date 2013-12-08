# PostgreSQL Job Queue Shootout

Yee-haw! To run:

    # Install PostgreSQL 9.2+ and Redis, if you haven't already.
    $ bundle
    $ DATABASE_URL=postgres://user:pass@localhost:5432/db-name rake

You may also need to pass REDIS_URL, if there isn't a server running on the local machine. Be aware that its data will be wiped out.

## Interpreting Results

This script measures the maximum throughput of a given Postgres installation when running DelayedJob, QueueClassic and Que. It does this by forking itself and hammering the database with many workers, while measuring how many jobs are worked per second. I designed Que specifically to have a very high throughput (workers don't block each other when locking jobs, and locking a job doesn't require a disk write), so it tends to win this benchmark.

The benchmark results can be significantly affected by how busy the disk and CPU are at a given moment, so by default they are run five times and the results are averaged. You may want to set the ITERATIONS environment variable to an even higher number if you're running on shared hardware like AWS.

### synchronous_commit

`synchronous_commit` is a configuration option in Postgres that tells it when to persist writes to the disk. With `synchronous_commit` turned on (which is the default, both for this shootout and for Postgres in general), Postgres won't return from a write until it's safely on disk, so the limiting factor will generally be how fast/busy your disk is. When `synchronous_commit` is turned off, Postgres will write all changes to disk at once every half a second or so, and the limiting factor will become CPU and the efficiency of each locking mechanism.

You can run the benchmark with `synchronous_commit` turned off, like so:

    $ DATABASE_URL=postgres://user:pass@localhost:5432/db-name SYNCHRONOUS_COMMIT=off rake

These results can be interesting, but in general you'll want to leave `synchronous_commit` on, to more accurately reflect the performance of each queue in production. Que tends to win either way, but the competition tends to be somewhat closer when `synchronous_commit` is off.

## Sample Output

These are the results from an AWS c3.8xlarge instance, with 32 cores and SSDs. Que came in at 7690.1 jobs per second, while DelayedJob reached 376.5 and QueueClassic reached 342.6. In other words, Que has a little over 20 times the throughput of DJ or QC on this hardware. I would expect Que to have an even greater advantage with more cores (which it can make better use of) or a slower, rotating disk (which it is less constrained by).

I'd be very curious to see results from dedicated hardware - I expect that without the inconsistencies of AWS, Que could reliably surpass 10,000 jobs per second, especially if the workers were moved to a different machine (I was unable to get two c3.8xlarge instances).

    Benchmarking delayed_job, queue_classic, que
      QUIET = false
      ITERATIONS = 5
      DATABASE_URL = postgres://postgres:@localhost/que-test
      JOB_COUNT = 1000
      TEST_PERIOD = 0.2
      WARMUP_PERIOD = 0.2
      SYNCHRONOUS_COMMIT = on

    Iteration #1:
    delayed_job: 1 => 124.8, 2 => 174.8, 3 => 314.6, 4 => 304.6, 5 => 389.5, 6 => 289.6, 7 => 404.5, 8 => 284.6, 9 => 239.7, 10 => 289.6, 11 => 289.6, 12 => 339.5
    delayed_job: Peaked at 7 workers with 404.5 jobs/second
    queue_classic: 1 => 84.9, 2 => 169.8, 3 => 229.7, 4 => 274.7, 5 => 284.7, 6 => 244.7, 7 => 294.6, 8 => 264.6, 9 => 239.7, 10 => 399.4, 11 => 334.6, 12 => 224.7, 13 => 319.5, 14 => 254.6, 15 => 219.5
    queue_classic: Peaked at 10 workers with 399.4 jobs/second
    que: 1 => 369.6, 2 => 624.3, 3 => 789.1, 4 => 734.1, 5 => 1468.2, 6 => 1313.2, 7 => 1967.7, 8 => 2226.9, 9 => 2586.6, 10 => 2551.9, 11 => 2856.5, 12 => 3310.7, 13 => 3525.6, 14 => 3674.9, 15 => 3130.8, 16 => 3829.0, 17 => 3854.1, 18 => 4212.9, 19 => 4108.8, 20 => 3983.9, 21 => 4437.7, 22 => 4767.9, 23 => 3804.7, 24 => 5322.4, 25 => 4641.2, 26 => 4457.6, 27 => 4648.0, 28 => 5195.9, 29 => 5520.1, 30 => 4831.2, 31 => 5690.9, 32 => 6231.4, 33 => 6136.0, 34 => 6964.4, 35 => 4532.2, 36 => 6025.4, 37 => 4927.4, 38 => 8985.1, 39 => 6414.9, 40 => 6334.2, 41 => 6796.2, 42 => 6905.6, 43 => 2711.1
    que: Peaked at 38 workers with 8985.1 jobs/second

    Iteration #2:
    delayed_job: 1 => 109.9, 2 => 159.8, 3 => 274.7, 4 => 314.6, 5 => 229.7, 6 => 274.6, 7 => 294.6, 8 => 284.6, 9 => 399.4, 10 => 274.6, 11 => 284.5, 12 => 369.5, 13 => 274.6, 14 => 364.5
    delayed_job: Peaked at 9 workers with 399.4 jobs/second
    queue_classic: 1 => 114.9, 2 => 199.8, 3 => 249.7, 4 => 249.7, 5 => 224.8, 6 => 204.8, 7 => 179.8, 8 => 194.8, 9 => 209.7
    queue_classic: Peaked at 4 workers with 249.7 jobs/second
    que: 1 => 204.8, 2 => 254.7, 3 => 559.4, 4 => 828.9, 5 => 1008.7, 6 => 1123.7, 7 => 1368.2, 8 => 1762.5, 9 => 1942.4, 10 => 1947.7, 11 => 2212.2, 12 => 2521.6, 13 => 2107.2, 14 => 2621.6, 15 => 2661.0, 16 => 2815.8, 17 => 2650.8, 18 => 2833.5, 19 => 3140.5, 20 => 3620.2, 21 => 3165.7, 22 => 2692.0, 23 => 2291.8, 24 => 3350.5, 25 => 3809.5, 26 => 2865.9, 27 => 3958.8, 28 => 5332.1, 29 => 5416.1, 30 => 4946.8, 31 => 4852.9, 32 => 5862.7, 33 => 7111.2, 34 => 8006.2, 35 => 6990.7, 36 => 6937.0, 37 => 6708.2, 38 => 5311.1, 39 => 5390.2
    que: Peaked at 34 workers with 8006.2 jobs/second

    Iteration #3:
    delayed_job: 1 => 124.9, 2 => 174.8, 3 => 269.7, 4 => 309.5, 5 => 314.6, 6 => 319.5, 7 => 374.4, 8 => 299.6, 9 => 279.6, 10 => 334.6, 11 => 374.5, 12 => 339.6, 13 => 329.6, 14 => 249.7, 15 => 324.5, 16 => 259.7
    delayed_job: Peaked at 11 workers with 374.5 jobs/second
    queue_classic: 1 => 134.9, 2 => 179.8, 3 => 354.6, 4 => 299.7, 5 => 409.5, 6 => 289.7, 7 => 354.6, 8 => 249.7, 9 => 339.6, 10 => 249.7
    queue_classic: Peaked at 5 workers with 409.5 jobs/second
    que: 1 => 354.6, 2 => 644.3, 3 => 104.9, 4 => 983.7, 5 => 1518.3, 6 => 1338.5, 7 => 1852.9, 8 => 1703.0, 9 => 2410.9, 10 => 1662.5, 11 => 2406.7, 12 => 2676.0, 13 => 2706.6, 14 => 2891.0, 15 => 3709.1, 16 => 3325.0, 17 => 2880.7, 18 => 2431.8, 19 => 3934.0, 20 => 4877.1, 21 => 4139.4, 22 => 4343.8, 23 => 4188.7, 24 => 4347.9, 25 => 4857.3
    que: Peaked at 20 workers with 4877.1 jobs/second

    Iteration #4:
    delayed_job: 1 => 89.9, 2 => 169.8, 3 => 234.7, 4 => 289.7, 5 => 324.6, 6 => 244.7, 7 => 304.6, 8 => 229.7, 9 => 214.7, 10 => 254.6
    delayed_job: Peaked at 5 workers with 324.6 jobs/second
    queue_classic: 1 => 124.9, 2 => 164.8, 3 => 289.6, 4 => 234.7, 5 => 249.7, 6 => 254.7, 7 => 224.7, 8 => 234.7
    queue_classic: Peaked at 3 workers with 289.6 jobs/second
    que: 1 => 299.7, 2 => 534.4, 3 => 644.2, 4 => 918.9, 5 => 1033.7, 6 => 1483.1, 7 => 1693.0, 8 => 1712.9, 9 => 1762.9, 10 => 2047.3, 11 => 2556.8, 12 => 2546.9, 13 => 2630.9, 14 => 2691.2, 15 => 2785.9, 16 => 3978.4, 17 => 3300.2, 18 => 2052.0, 19 => 4232.7, 20 => 0.0, 21 => 4058.4, 22 => 3344.6, 23 => 3864.4, 24 => 4443.2, 25 => 5227.8, 26 => 4718.0, 27 => 5886.4, 28 => 6698.9, 29 => 5489.7, 30 => 6867.8, 31 => 3869.5, 32 => 6783.7, 33 => 7316.7, 34 => 5696.1, 35 => 6842.3, 36 => 6117.0, 37 => 5946.2, 38 => 6923.6
    que: Peaked at 33 workers with 7316.7 jobs/second

    Iteration #5:
    delayed_job: 1 => 104.9, 2 => 194.8, 3 => 259.7, 4 => 379.6, 5 => 319.6, 6 => 334.5, 7 => 324.5, 8 => 189.8, 9 => 284.6
    delayed_job: Peaked at 4 workers with 379.6 jobs/second
    queue_classic: 1 => 99.9, 2 => 174.8, 3 => 319.6, 4 => 289.7, 5 => 354.6, 6 => 339.5, 7 => 364.5, 8 => 289.6, 9 => 249.7, 10 => 189.8, 11 => 259.7, 12 => 249.7
    queue_classic: Peaked at 7 workers with 364.5 jobs/second
    que: 1 => 339.6, 2 => 669.3, 3 => 774.1, 4 => 809.1, 5 => 1003.9, 6 => 1353.3, 7 => 1753.1, 8 => 1882.8, 9 => 2422.2, 10 => 2042.5, 11 => 2432.0, 12 => 2012.4, 13 => 2541.8, 14 => 2471.9, 15 => 2666.5, 16 => 3108.5, 17 => 3719.6, 18 => 3379.3, 19 => 3095.5, 20 => 3799.3, 21 => 5004.4, 22 => 3532.6, 23 => 3355.1, 24 => 5076.7, 25 => 4328.4, 26 => 4264.9, 27 => 5251.2, 28 => 5366.3, 29 => 5727.1, 30 => 4902.2, 31 => 4228.2, 32 => 5815.1, 33 => 6079.6, 34 => 6140.8, 35 => 7766.6, 36 => 9087.1, 37 => 9039.9, 38 => 9265.2, 39 => 6948.1, 40 => 8666.3, 41 => 7756.3, 42 => 7764.1, 43 => 5013.6
    que: Peaked at 38 workers with 9265.2 jobs/second

    delayed_job jobs per second: avg = 376.5, max = 404.5, min = 324.6, stddev = 31.7
    queue_classic jobs per second: avg = 342.6, max = 409.5, min = 249.7, stddev = 70.0
    que jobs per second: avg = 7690.1, max = 9265.2, min = 4877.1, stddev = 1754.3

    Total runtime: 198.7 seconds
