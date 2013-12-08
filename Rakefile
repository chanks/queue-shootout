task :default do
  task_start = Time.now

  require 'uri'
  require 'bundler'
  Bundler.require

  ITERATIONS         = (ENV['ITERATIONS'] || 5).to_i
  TEST_PERIOD        = (ENV['TEST_PERIOD'] || 0.2).to_f
  JOB_COUNT          = (ENV['JOB_COUNT'] || 1000).to_i
  SYNCHRONOUS_COMMIT = ENV['SYNCHRONOUS_COMMIT'] || 'on'

  QUEUES = {}

  DATABASE_URL = ENV['DATABASE_URL'] || 'postgres://postgres:@localhost/que-test'
  DATABASE_URI = URI.parse(DATABASE_URL)

  NEW_PG = -> do
    pg = PG::Connection.open :host     => DATABASE_URI.host,
                             :user     => DATABASE_URI.user,
                             :password => DATABASE_URI.password,
                             :port     => DATABASE_URI.port || 5432,
                             :dbname   => DATABASE_URI.path[1..-1]

    pg.async_exec "SET SESSION synchronous_commit = #{SYNCHRONOUS_COMMIT}"
    pg.async_exec "SET client_min_messages TO 'warning'" # Avoid annoying notice messages.
    pg
  end

  # We have to watch our database connections, because they'll become unusable
  # whenever we fork. This pg connection is only used during setup in the main
  # process, and the redis connection is reestablished after forking.
  $pg    = NEW_PG.call
  $redis = Redis.new :url    => ENV['REDIS_URL'],
                     :driver => :hiredis

  %w(delayed_job queue_classic que).each { |queue| require "./queues/#{queue}" }

  $pg.async_exec "ANALYZE"



  # For large numbers of workers, we remove Ruby's GIL as the bottleneck by
  # forking off child processes to act as workers, while the parent process
  # manages them and tracks their performance.

  parent_pid = Process.pid
  define_method(:parent?) { parent_pid == Process.pid }

  puts "Benchmarking #{QUEUES.keys.join(', ')}"
  puts "  ITERATIONS = #{ITERATIONS}"
  puts "  DATABASE_URL = #{DATABASE_URL}"
  puts "  JOB_COUNT = #{JOB_COUNT}"
  puts "  TEST_PERIOD = #{TEST_PERIOD}"
  puts "  SYNCHRONOUS_COMMIT = #{SYNCHRONOUS_COMMIT}"
  puts

  peaks = {}

  ITERATIONS.times do |i|
    puts "Iteration ##{i + 1}:"

    QUEUES.each do |queue, procs|
      peaks[queue] ||= []
      worker_count   = 1
      rates          = []

      print "#{queue}: "

      loop do
        $redis.flushdb
        worker_count.times { Process.fork if parent? }
        $redis.client.reconnect

        if parent?
          # Give workers a chance to warm up before we start tracking their progress.
          sleep 0.2

          # Reset the counter and count the jobs done over TEST_PERIOD seconds.
          # Ruby may let this thread sleep longer than TEST_PERIOD, so don't
          # trust that value, and actually measure the elapsed time.
          $redis.set 'job-count', 0
          start = Time.now
          sleep TEST_PERIOD
          count = $redis.get('job-count').to_i
          elapsed_time = Time.now - start
          rates << (count / elapsed_time)

          # Signal child processes to exit.
          $redis.set 'job-count', -1_000_000

          Process.waitall
        else
          # We're a child/worker process. First, establish connections.
          procs[:setup].call

          loop do
            # Work job.
            procs[:work].call

            # Mark job as completed. If this is negative, it means we're shutting down.
            break if $redis.incr('job-count') < 0
          end

          exit
        end

        print "#{rates.count} => #{rates.last.round(1)}"

        # If there were three previous rates and this one was lower than all three,
        # assume the slope is trending down and we're done.
        recent = rates.last(4)
        if recent.length == 4 && recent.last == recent.min
          peak  = rates.max
          count = rates.index(peak) + 1

          puts
          puts "#{queue}: Peaked at #{count} workers with #{peak.round(1)} jobs/second\n"

          peaks[queue] << peak

          break
        else
          # Try again with one more worker.
          print ", "
          worker_count += 1
        end
      end
    end

    puts
  end

  peaks.each do |queue, array|
    puts "#{queue} peak average: #{(array.inject(:+) / array.length).round(1)} jobs per second"
  end

  puts
  puts "Total runtime: #{(Time.now - task_start).round(1)} seconds"
end
