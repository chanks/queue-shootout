$pg.async_exec <<-SQL
  DROP TABLE IF EXISTS delayed_jobs;

  CREATE TABLE delayed_jobs
  (
    id serial NOT NULL,
    priority integer NOT NULL DEFAULT 0,
    attempts integer NOT NULL DEFAULT 0,
    handler text NOT NULL,
    last_error text,
    run_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_at timestamp without time zone,
    locked_by character varying(255),
    queue character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id)
  );

  CREATE INDEX delayed_jobs_priority ON delayed_jobs USING btree (priority, run_at);

  INSERT INTO delayed_jobs (handler, run_at, created_at, updated_at)
  SELECT '--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/module ''DJPerpetualJob''\nmethod_name: :run\nargs: []\n', now(), now(), now()
  FROM generate_Series(1,#{JOB_COUNT}) AS i;
SQL

module DJPerpetualJob
  class << self
    def run(*args)
      ActiveRecord::Base.transaction do
        delay.run
        # Again, not sure how to delete job in the same transaction.
      end
    end
  end
end

QUEUES[:delayed_job] = {
  :setup => -> {
    ActiveRecord::Base.establish_connection(DATABASE_URL)
    ActiveRecord::Base.connection.raw_connection.async_exec "SET SESSION synchronous_commit = #{SYNCHRONOUS_COMMIT}"
    $worker = Delayed::Worker.new
  },
  :work => -> { $worker.work_off(1) }
}
