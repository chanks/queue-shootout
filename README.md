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

These are the results when running on my quad-core i5 laptop, with a relatively slow 5400 rpm hard drive.

    $ ITERATIONS=10 rake
    Benchmarking delayed_job, queue_classic, que
      ITERATIONS = 10
      DATABASE_URL = postgres://postgres:@localhost/que-test
      JOB_COUNT = 1000
      TEST_PERIOD = 1.0
      SYNCHRONOUS_COMMIT = on

    Iteration #1:
    delayed_job: 1 => 29.0, 2 => 31.0, 3 => 41.0, 4 => 49.0, 5 => 49.0, 6 => 30.0
    delayed_job: Peaked at 5 workers with 49.0 jobs/second
    queue_classic: 1 => 31.0, 2 => 28.0, 3 => 45.0, 4 => 44.0, 5 => 44.0, 6 => 50.0, 7 => 45.0, 8 => 49.0, 9 => 31.0
    queue_classic: Peaked at 6 workers with 50.0 jobs/second
    que: 1 => 86.9, 2 => 79.0, 3 => 94.0, 4 => 174.9, 5 => 207.9, 6 => 245.9, 7 => 288.9, 8 => 320.9, 9 => 387.8, 10 => 313.8, 11 => 243.9
    que: Peaked at 9 workers with 387.8 jobs/second

    Iteration #2:
    delayed_job: 1 => 29.0, 2 => 28.0, 3 => 45.0, 4 => 39.0, 5 => 51.0, 6 => 47.0, 7 => 48.0, 8 => 50.0, 9 => 36.0
    delayed_job: Peaked at 5 workers with 51.0 jobs/second
    queue_classic: 1 => 30.0, 2 => 30.0, 3 => 42.0, 4 => 47.0, 5 => 47.0, 6 => 26.0
    queue_classic: Peaked at 5 workers with 47.0 jobs/second
    que: 1 => 87.9, 2 => 84.0, 3 => 56.0, 4 => 84.0, 5 => 211.9, 6 => 191.9, 7 => 310.9, 8 => 358.6, 9 => 310.9, 10 => 114.0
    que: Peaked at 8 workers with 358.6 jobs/second

    Iteration #3:
    delayed_job: 1 => 18.0, 2 => 24.0, 3 => 43.0, 4 => 47.0, 5 => 53.0, 6 => 49.0, 7 => 50.0, 8 => 46.0
    delayed_job: Peaked at 5 workers with 53.0 jobs/second
    queue_classic: 1 => 30.0, 2 => 31.0, 3 => 43.0, 4 => 40.0, 5 => 45.0, 6 => 48.0, 7 => 43.0, 8 => 46.0, 9 => 50.0, 10 => 42.0
    queue_classic: Peaked at 9 workers with 50.0 jobs/second
    que: 1 => 67.0, 2 => 53.0, 3 => 135.9, 4 => 175.9, 5 => 185.9, 6 => 271.7, 7 => 288.7, 8 => 72.0
    que: Peaked at 7 workers with 288.7 jobs/second

    Iteration #4:
    delayed_job: 1 => 30.0, 2 => 28.0, 3 => 46.0, 4 => 46.0, 5 => 30.0, 6 => 53.0, 7 => 43.0, 8 => 51.0, 9 => 53.0, 10 => 38.0
    delayed_job: Peaked at 9 workers with 53.0 jobs/second
    queue_classic: 1 => 29.0, 2 => 28.0, 3 => 44.0, 4 => 45.0, 5 => 51.0, 6 => 29.0
    queue_classic: Peaked at 5 workers with 51.0 jobs/second
    que: 1 => 88.0, 2 => 91.0, 3 => 123.9, 4 => 180.9, 5 => 186.9, 6 => 226.9, 7 => 302.9, 8 => 332.8, 9 => 398.8, 10 => 100.8
    que: Peaked at 9 workers with 398.8 jobs/second

    Iteration #5:
    delayed_job: 1 => 15.0, 2 => 30.0, 3 => 46.0, 4 => 49.0, 5 => 52.0, 6 => 53.0, 7 => 47.0
    delayed_job: Peaked at 6 workers with 53.0 jobs/second
    queue_classic: 1 => 27.0, 2 => 30.0, 3 => 37.0, 4 => 42.0, 5 => 47.0, 6 => 43.0, 7 => 47.0, 8 => 42.0
    queue_classic: Peaked at 5 workers with 47.0 jobs/second
    que: 1 => 72.0, 2 => 90.9, 3 => 111.0, 4 => 180.9, 5 => 225.9, 6 => 257.9, 7 => 267.9, 8 => 345.8, 9 => 357.8, 10 => 430.7, 11 => 311.9
    que: Peaked at 10 workers with 430.7 jobs/second

    Iteration #6:
    delayed_job: 1 => 29.0, 2 => 30.0, 3 => 29.0, 4 => 45.0, 5 => 40.0, 6 => 48.0, 7 => 53.0, 8 => 44.0, 9 => 54.0, 10 => 46.0, 11 => 43.0
    delayed_job: Peaked at 9 workers with 54.0 jobs/second
    queue_classic: 1 => 30.0, 2 => 31.0, 3 => 43.0, 4 => 46.0, 5 => 44.0, 6 => 49.0, 7 => 36.0
    queue_classic: Peaked at 6 workers with 49.0 jobs/second
    que: 1 => 84.0, 2 => 87.0, 3 => 115.9, 4 => 153.9, 5 => 215.9, 6 => 271.9, 7 => 304.8, 8 => 122.0
    que: Peaked at 7 workers with 304.8 jobs/second

    Iteration #7:
    delayed_job: 1 => 30.0, 2 => 30.0, 3 => 42.0, 4 => 47.0, 5 => 52.0, 6 => 51.0, 7 => 50.0, 8 => 27.0
    delayed_job: Peaked at 5 workers with 52.0 jobs/second
    queue_classic: 1 => 30.0, 2 => 31.0, 3 => 41.0, 4 => 46.0, 5 => 44.0, 6 => 49.0, 7 => 33.0
    queue_classic: Peaked at 6 workers with 49.0 jobs/second
    que: 1 => 29.0, 2 => 87.0, 3 => 135.9, 4 => 100.0, 5 => 225.9, 6 => 271.9, 7 => 296.9, 8 => 315.5, 9 => 371.9, 10 => 409.8, 11 => 310.8
    que: Peaked at 10 workers with 409.8 jobs/second

    Iteration #8:
    delayed_job: 1 => 29.0, 2 => 31.0, 3 => 42.0, 4 => 52.0, 5 => 51.0, 6 => 49.0, 7 => 46.0
    delayed_job: Peaked at 4 workers with 52.0 jobs/second
    queue_classic: 1 => 27.0, 2 => 28.0, 3 => 46.0, 4 => 41.0, 5 => 47.0, 6 => 48.0, 7 => 43.9, 8 => 45.0, 9 => 25.0
    queue_classic: Peaked at 6 workers with 48.0 jobs/second
    que: 1 => 88.0, 2 => 91.0, 3 => 122.9, 4 => 180.9, 5 => 207.9, 6 => 258.9, 7 => 277.9, 8 => 349.7, 9 => 393.8, 10 => 331.9, 11 => 165.9
    que: Peaked at 9 workers with 393.8 jobs/second

    Iteration #9:
    delayed_job: 1 => 29.0, 2 => 17.0, 3 => 40.0, 4 => 39.0, 5 => 42.0, 6 => 30.0
    delayed_job: Peaked at 5 workers with 42.0 jobs/second
    queue_classic: 1 => 24.0, 2 => 24.0, 3 => 32.0, 4 => 34.8, 5 => 39.0, 6 => 36.0, 7 => 36.0, 8 => 43.0, 9 => 42.8, 10 => 31.9
    queue_classic: Peaked at 8 workers with 43.0 jobs/second
    que: 1 => 84.0, 2 => 89.0, 3 => 125.9, 4 => 163.0, 5 => 156.0, 6 => 245.8, 7 => 209.9, 8 => 215.9, 9 => 337.9, 10 => 249.9, 11 => 395.9, 12 => 249.9
    que: Peaked at 11 workers with 395.9 jobs/second

    Iteration #10:
    delayed_job: 1 => 22.0, 2 => 24.0, 3 => 43.0, 4 => 50.0, 5 => 51.0, 6 => 48.0, 7 => 52.0, 8 => 50.0, 9 => 44.0
    delayed_job: Peaked at 7 workers with 52.0 jobs/second
    queue_classic: 1 => 28.0, 2 => 18.0, 3 => 45.0, 4 => 48.0, 5 => 39.0, 6 => 47.0, 7 => 47.0, 8 => 42.0, 9 => 44.8, 10 => 42.0, 11 => 35.0
    queue_classic: Peaked at 4 workers with 48.0 jobs/second
    que: 1 => 87.0, 2 => 84.0, 3 => 129.0, 4 => 86.9, 5 => 218.9, 6 => 268.9, 7 => 276.9, 8 => 356.8, 9 => 341.9, 10 => 378.8, 11 => 478.9, 12 => 510.8, 13 => 521.8, 14 => 568.9, 15 => 496.5
    que: Peaked at 14 workers with 568.9 jobs/second

    delayed_job peak average: 51.1 jobs per second
    queue_classic peak average: 48.2 jobs per second
    que peak average: 393.8 jobs per second

    Total runtime: 370.4 seconds
