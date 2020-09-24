$pg.async_exec "DROP TABLE IF EXISTS queue_classic_jobs CASCADE"
$pg.async_exec "DROP FUNCTION IF EXISTS queue_classic_notify()"

QC.default_conn_adapter = QC::ConnAdapter.new(connection: $pg)
QC::Setup.create($pg)

$pg.async_exec <<-SQL
  INSERT INTO queue_classic_jobs (q_name, method, args)
  SELECT 'default', 'QCPerpetualJob.run', '[]'
  FROM generate_Series(1,#{JOB_COUNT}) AS i;
SQL

module QCPerpetualJob
  class << self
    def run(*args)
      QC.default_conn_adapter.execute "begin"
      QC.enqueue "QCPerpetualJob.run"
      # Not sure how to delete this job in the same transaction?
      QC.default_conn_adapter.execute "commit"
    end
  end
end

QUEUES[:queue_classic] = {
  :setup => -> {
    pg = NEW_PG.call
    QC.default_conn_adapter = QC::ConnAdapter.new(connection: pg)
    $worker = QC::Worker.new(:connection => pg)
  },
  :work => -> { $worker.work }
}
