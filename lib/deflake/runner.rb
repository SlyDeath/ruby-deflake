# frozen_string_literal: true

module Deflake
  # Runs a test file many times, each in a fresh process with a new seed
  class Runner
    # Seeds Minitest and RSpec accept
    SEEDS = 0xFFFF

    # only: run just one test, by its Summary#id; jobs: how many processes at once
    def initialize(path, runs:, only: nil, jobs: 1, adapter: Adapters.for(path))
      raise ArgumentError, "runs must be positive" unless runs.positive?
      raise ArgumentError, "jobs must be positive" unless jobs.positive?

      @path = path
      @count = runs
      @only = only
      @jobs = jobs
      @adapter = adapter
    end

    # Ids of every test that started in the last call, even those left out of its result
    attr_reader :seen
    # Every summary of the last call, the quiet ones too, and every test's name by its id
    attr_reader :all, :names
    # Databases that test processes running at once used together in the last call
    attr_reader :shared_databases

    # Returns a hash of test id => Summary. Runs where a test skipped itself count only for its
    # leaks, and a test that skipped itself every time and leaked nothing is left out.
    # Errors outside of any test, in a run of the whole file, show up as Execution::OUTSIDE
    def call
      databases = SharedDatabases.new
      rows = databases.watch(@jobs) do |folder|
        in_parallel(seeds) { |seed, worker| execute(seed, worker_env(worker, folder)) }
      end
      @shared_databases = databases.shared
      check_some_ran(rows)
      check_some_tests(rows)
      # The id, not the name: RSpec examples can share a description
      remember(rows.group_by { |row| row["id"] })
      @all.reject { |id, summary| quiet?(id, summary) }
    end

    private

    def remember(groups)
      @seen = groups.keys
      @all = groups.to_h { |id, group| [id, summarize(id, group)] }
      @names = @all.transform_values(&:name)
    end

    # A run that broke before its first test is reported among the others, unless every run did
    def check_some_ran(rows)
      silent = rows.select { |row| row.key?("output") }
      return if silent.empty? || silent.size < rows.size

      raise Execution::NoResults.new(ResultFile.clean(@path), silent.first["output"], silent.first["ending"])
    end

    # A file without tests, or whose tests a filter of the project leaves out, is a mistake, as a
    # line without a test is: a passing report would hide it
    def check_some_tests(rows)
      return if @only || rows.any? { |row| row["id"] != Execution::OUTSIDE || row["ran"] }
      return unless rows.all? { |row| quiet_outside?(row) }

      raise Error, "no tests ran in #{ResultFile.clean(@path)} (no tests in it, or a filter leaves them all out)"
    end

    def quiet_outside?(row)
      row["passed"] && row["leaks"].empty?
    end

    # Each run gets a seed of its own while there are enough of them
    def seeds
      return Array.new(@count) { rand(SEEDS) } if @count > SEEDS

      (0...SEEDS).to_a.sample(@count)
    end

    def execute(seed, env)
      return Execution.whole_file(@adapter, @path, seed: seed, env: env) unless @only

      Execution.some(@adapter, @path, seed: seed, only: @only, env: env)
    end

    # Threads only wait for the test processes, so they do not fight over Ruby's lock
    def in_parallel(seeds, &block)
      queue = Queue.new(seeds).tap(&:close)
      workers = Array.new([@jobs, seeds.size].min) do |worker|
        Thread.new do
          # The error reaches the caller through Thread#value, no need to print it here too
          Thread.current.report_on_exception = false
          drain(queue, worker, &block)
        end
      end
      workers.flat_map(&:value)
    ensure
      stop(workers)
    end

    # On an error or an interrupt the other workers stop too, killing their test processes
    def stop(workers)
      workers&.each(&:kill)&.each do |worker|
        worker.join
      rescue StandardError
        nil
      end
    end

    def drain(queue, worker)
      rows = []
      while (seed = queue.pop)
        rows.concat(yield(seed, worker))
      end
      rows
    end

    # Same convention as parallel_tests: "", "2", "3"... so each process can use its own database
    def worker_env(worker, folder)
      return {} if @jobs == 1

      { "TEST_ENV_NUMBER" => worker.zero? ? "" : (worker + 1).to_s, ResultFile::DATABASES_KEY => folder }
    end

    # Leaks outside of tests, such as those of a before(:all) hook, are not quiet either
    def quiet?(id, summary)
      return summary.failures.zero? && summary.leaks.empty? if id == Execution::OUTSIDE

      summary.total.zero? && summary.leaks.empty?
    end

    def summarize(id, rows)
      skipped, ran = rows.partition { |row| row["skipped"] }
      runs = ran.map do |row|
        Run.new(seed: row["seed"], passed: row["passed"], error: row["error"], leaks: row.fetch("leaks", []),
                group: row["group"])
      end
      Summary.new(runs, id: id, name: name_of(rows), skipped: skipped.size,
                        skipped_leaks: skipped.flat_map { |row| row.fetch("leaks", []) })
    end

    # RSpec names a one-liner only once its matcher runs, so a passing run has the full name
    def name_of(rows)
      named = rows.select { |row| row["passed"] }
      named = rows if named.empty?
      named.map { |row| row["name"] }.tally.max_by(&:last).first
    end
  end
end
