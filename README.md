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
