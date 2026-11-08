# frozen_string_literal: true

require "tmpdir"
require_relative "outcome"

module Deflake
  # Runs a test file once in a fresh process and returns one row per test that started, in run order
  module Execution
    # Id of the row that stands for errors outside of any test, such as in an after(:context) hook
    OUTSIDE = "(outside of tests)"
    # Runs the tests of a process one at a time
    SERIAL = { "PARALLEL_WORKERS" => "1", "MT_CPU" => "1" }.freeze
    # Raised when a test process wrote no results at all; output is what it printed,
    # ending how the process ended, such as "timed out after 5 seconds"
    class NoResults < Error
      attr_reader :output, :ending

      # success: whether the process itself exited with success
      def initialize(target, output, ending = nil, success: false)
        @output = output
        @ending = ending
        @success = success
        super("#{target} produced no test results#{" (the test process #{ending})" if ending}:\n#{output}")
      end

      def success? = @success
    end

    class << self
      # Seconds a test process may run before it is killed, nil for no limit
      attr_accessor :timeout

      # only: what to run instead of the whole file; env: extra environment variables for the test process
      def call(adapter, path, seed:, only: nil, env: {})
        complete(run(adapter, path, seed, only, env), only || path).rows
      end

      # The ids of the whole file's tests in the order they ran, and whether tests that cannot run
      # by name, such as those in a class without a name, ran too
      def order(adapter, path, seed:)
        process = complete(run(adapter, path, seed, nil, {}), path)
        [process.rows.map { |row| row["id"] }, process.unnamed.any?]
      end

      # Tries again when the test process wrote no results, as a flaky boot does now and then
      def retrying(attempts = 3)
        yield
      rescue NoResults
        attempts -= 1
        retry if attempts.positive?
        raise
      end

      # Runs the whole file and adds an OUTSIDE row telling whether the process failed on its own.
      # A process that wrote no results at all is one failed OUTSIDE row carrying its output
      def whole_file(adapter, path, seed:, env: {})
        process = run(adapter, path, seed, nil, env)
        return [no_results_row(seed, process)] unless process.rows

        process.rows + [outside_row(process, seed)]
      end

      # Runs only some tests. As in whole_file, a process that wrote no results is a failed OUTSIDE
      # row, and so is one where none of these tests started: only a failure that cannot run by
      # name, such as a class-level hook, may have run
      def some(adapter, path, seed:, only:, env: {})
        process = run(adapter, path, seed, only, env)
        process.rows.nil? || process.rows.empty? ? [no_results_row(seed, process)] : process.rows
      end

      def no_results_row(seed, process)
        message = "the test process #{ending(process.status)} before any test finished"
        failures = outside_failures(process)
        error = failures ? "#{message}:\n#{failures}" : with_tail(message, process.output)
        { "id" => OUTSIDE, "name" => "errors outside of tests", "passed" => false, "seed" => seed,
          "error" => error, "output" => process.output, "ending" => ending(process.status), "leaks" => [] }
      end

      def ending(status) = Child.ending(status)

      def with_tail(message, output) = Tail.with(message, output)

      private

      def complete(process, target)
        return process if process.rows

        raise NoResults.new(ResultFile.clean(Array(target).join(" ")), process.output, ending(process.status),
                            success: process.status.success?)
      end

      def run(adapter, path, seed, only, env)
        Dir.mktmpdir do |dir|
          output = File.join(dir, "results.jsonl")
          log = File.join(dir, "output.log")
          # Rails' parallelize and Minitest's parallelize_me! would run tests at once, in no fixed
          # order, and the leaks of one would show up in the others. Variables a test process of an
          # outer deflake got are not passed on
          env = ResultFile::KEYS.to_h { |key| [key, nil] }
                                .merge(env, adapter.env(only), ResultFile::ENV_KEY => output, **SERIAL)
          status = Child.run(env, adapter.command(path, seed: seed, only: only), log, timeout)
          finish(File.exist?(output) ? ResultFile.read(output) : nil, seed, status, ResultFile.clean(Tail.read(log)))
        end
      end

      # A test that started and never finished took its process down with it, so it counts as failed.
      # A failure that cannot be run alone by name, such as a test in a class without a name or a
      # class-level hook, is told about as an error outside of tests. A process that wrote nothing,
      # or failed before any test, has no rows
      def finish(rows, seed, status, output)
        return Outcome.new(nil, [], [], status, output) unless rows

        outside, rows = rows.partition { |row| row.key?("outside") }
        unnamed, rows = rows.partition { |row| row.key?("unnamed") }
        outcome = Outcome.new(tests(rows, seed, status, output), unnamed, outside, status, output)
        outcome.rows = nil unless outcome.rows.any? || outcome.unnamed_failures.any? || status.success?
        outcome
      end

      def tests(rows, seed, status, output)
        started, finished = without_repeats(rows).partition { |row| row.key?("started") }
        finished + lost(started, finished, seed, status, output)
      end

      # One result each time a test starts: RSpec may report an example again, without starting it,
      # when its group breaks afterwards
      def without_repeats(rows)
        running = Hash.new(0)
        rows.select do |row|
          next running[row["started"]] += 1 if row.key?("started")
          next true unless row.key?("id")

          running[row["id"]].positive?.tap { |started| running[row["id"]] -= 1 if started }
        end
      end

      def lost(started, finished, seed, status, output)
        done = finished.to_h { |row| [row["id"], true] }
        message = "the test process #{ending(status)} during this test"
        started.reject { |row| done[row["started"]] }.uniq { |row| row["started"] }.map do |row|
          # What the output shows before the crash changes with the order of the tests
          { "id" => row["started"], "name" => row["name"], "passed" => false, "seed" => seed,
            "error" => with_tail(message, output), "group" => message,
            "timed_out" => status.is_a?(TimedOut), "leaks" => [] }
        end
      end

      # A process that failed while every test passed broke somewhere else, for example in a hook.
      # Errors outside of tests that the test framework told about count even when a test failed.
      # ran: whether any test ran, even one that cannot run by name
      def outside_row(process, seed)
        error = outside_failures(process)
        passed = error.nil? && (process.status.success? || process.failed_test?)
        { "id" => OUTSIDE, "name" => "errors outside of tests", "passed" => passed, "seed" => seed,
          "error" => (passed ? nil : error || outside_tail(process)), "leaks" => process.leaks, "ran" => process.ran? }
      end

      def outside_tail(process)
        with_tail("the test process #{ending(process.status)} although no test failed", process.output)
      end

      # Sorted, as the order they happened in changes with the seed
      def outside_failures(process)
        failures = process.unnamed_failures.map { |row| "#{row["unnamed"]}: #{row["error"]}" }.uniq.sort
        failures.unshift("a failure deflake cannot run alone by name:") if failures.any?
        text = (process.outside.filter_map { |row| row["outside"] }.uniq.sort + failures).join("\n")
        text unless text.empty?
      end
    end

    TimedOut = Child::TimedOut
  end
end
