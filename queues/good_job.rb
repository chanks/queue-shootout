require 'active_job'

$pg.async_exec <<-SQL
  DROP TABLE IF EXISTS good_jobs;

  CREATE EXTENSION IF NOT EXISTS pgcrypto;

  CREATE TABLE good_jobs (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    queue_name text,
    priority integer,
    serialized_params jsonb,
    scheduled_at timestamp without time zone,
    performed_at timestamp without time zone,
    finished_at timestamp without time zone,
    error text
  );

  CREATE INDEX index_good_jobs_on_queue_name_and_scheduled_at ON public.good_jobs USING btree (queue_name, scheduled_at) WHERE (finished_at IS NULL);
  CREATE INDEX index_good_jobs_on_scheduled_at ON public.good_jobs USING btree (scheduled_at) WHERE (finished_at IS NULL);

  INSERT INTO "good_jobs" ("created_at", "updated_at", "queue_name", "priority", "serialized_params", "scheduled_at")
  SELECT NOW(), NOW(), 'default', 0, '{\"job_class\":\"GoodJobPerpetualJob\",\"job_id\":\"31f0ac5d-185a-4cbb-a22b-64c9b9839617\",\"provider_job_id\":null,\"queue_name\":\"default\",\"priority\":0,\"arguments\":[],\"executions\":0,\"exception_executions\":{},\"locale\":\"en\",\"timezone\":\"UTC\",\"enqueued_at\":\"2020-09-21T14:16:16Z\"}', NOW()
  FROM generate_Series(1,#{JOB_COUNT}) AS i;
SQL


class GoodJobPerpetualJob < ActiveJob::Base
  def perform
  end
end

ActiveJob::Base.logger = nil
GoodJob::Job.primary_key = :id

QUEUES[:good_job] = {
  :setup => -> {
    ActiveRecord::Base.establish_connection(DATABASE_URL)
    ActiveRecord::Base.connection.raw_connection.async_exec "SET SESSION synchronous_commit = #{SYNCHRONOUS_COMMIT}"
  },
  :work => -> { GoodJob::Job.perform_with_advisory_lock }
}
