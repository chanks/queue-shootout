# PostgreSQL Job Queue Shootout

Yee-haw! To run:

    # Install PostgreSQL 9.2+ and Redis, if you haven't already.
    $ bundle
    $ DATABASE_URL=postgres://user:pass@localhost:5432/db-name rake
    # You may also need to pass REDIS_URL, if there isn't a server running on the local machine.
