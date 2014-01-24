$pg.async_exec "DROP TABLE IF EXISTS que_jobs"

Que.connection = $pg
Que.migrate!

$pg.async_exec <<-SQL
  INSERT INTO que_jobs (job_class, priority)
  SELECT 'QuePerpetualJob', 1
  FROM generate_Series(1,#{JOB_COUNT}) AS i;
SQL

class QuePerpetualJob < Que::Job
  def run
    Que.execute "begin"
    self.class.queue
    destroy
    Que.execute "commit"
  end
end

QUEUES[:que] = {
  :setup => -> { Que.connection = NEW_PG.call },
  :work  => -> { Que::Job.work }
}
