$pg.async_exec "DROP TABLE IF EXISTS queue_classic_jobs CASCADE"
$pg.async_exec "DROP FUNCTION IF EXISTS queue_classic_notify()"

# Set up QueueClassic.
QC::Conn.connection = $pg
QC::Setup.create

$pg.async_exec <<-SQL
  INSERT INTO queue_classic_jobs (q_name, method, args)
  SELECT 'default', 'QCPerpetualJob.run', '[]'
  FROM generate_Series(1,#{JOB_COUNT}) AS i;
SQL

module QCPerpetualJob
  class << self
    def run(*args)
      QC::Conn.connection.async_exec "begin"
      QC.enqueue "QCPerpetualJob.run"
      # Not sure how to delete this job in the same transaction?
      QC::Conn.connection.async_exec "commit"
    end
  end
end

QUEUES[:queue_classic] = {
  :setup => -> {
    QC::Conn.connection = NEW_PG.call
    $worker = QC::Worker.new
  },
  :work => -> { $worker.work }
}
