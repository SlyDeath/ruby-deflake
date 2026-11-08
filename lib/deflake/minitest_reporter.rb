# frozen_string_literal: true

require "minitest"
require_relative "result_file"
require_relative "leaks"
require_relative "minitest_tests"

module Deflake
  # Writes the result of every test to a file, one JSON line per test.
  # Also checks every test for leaks: prerecord and record run outside the test's
  # own run method, so whatever Rails does around it (the executor clearing
  # Current, a rolled back transaction) has already happened.
  # Tests in anonymous classes have no name to run them by, and results that are not tests (a
  # class-level hook such as minitest-hooks' before_all reports its error as a result) cannot be
  # run alone: their failures are written as failures outside of tests
  class MinitestReporter < Minitest::AbstractReporter
    class << self
      # The reporter of this process, nil until Minitest starts it
      attr_accessor :current
    end

    def initialize(path, seed)
      super()
      @path = path
      @seed = seed
      # Test id => state before it. parallelize_me! runs several tests at once
      @before = {}
      # Every leak the tests reported so far
      @leaks = []
      @lock = Mutex.new
      ResultFile.start(path)
      self.class.current = self
    end

    def prerecord(klass, name)
      prefix = MinitestTests.prefix(klass) or return

      id = "#{prefix}##{name}"
      ResultFile.append(@path, started: id, name: id)
      snapshot = Leaks.snapshot
      @lock.synchronize { @before[id] = snapshot }
    end

    def record(result)
      return record_unnamed(result, "#{result.name} (in a class without a name)") unless result.klass

      id, before = @lock.synchronize { take(result) }
      # Every test Minitest runs is prerecorded first
      return record_unnamed(result, "#{id} (not a test)") unless before

      leaks = Leaks.since(before)
      @lock.synchronize { @leaks.concat(leaks) }
      return ResultFile.append(@path, id: id, name: id, skipped: true, seed: @seed, leaks: leaks) if result.skipped?

      ResultFile.append(@path, id: id, name: id, passed: result.passed?, seed: @seed,
                               error: error_message(result.failure), leaks: leaks)
    end

    # Leaks of a whole class that none of its tests reported, as errors outside of tests
    def around_class(klass)
      before = Leaks.snapshot
      reported = @leaks.size
      yield
    ensure
      leaks = Leaks.own(Leaks.since(before), @leaks.drop(reported)) if before
      if leaks&.any?
        label = MinitestTests.prefix(klass) || "a class without a name"
        ResultFile.append(@path, outside: nil, leaks: leaks.map { |leak| "#{label}, outside its tests: #{leak}" })
      end
    end

    private

    # The id of the test this result is for, and the state before it. A result names only its
    # class, so of two classes with the same name the one whose test started is meant
    def take(result)
      ids = MinitestTests.named(result.klass).map { |klass| "#{MinitestTests.prefix(klass)}##{result.name}" }
      ids = ["#{result.klass}##{result.name}"] if ids.empty?
      id = ids.find { |candidate| @before.key?(candidate) } || ids.first
      [id, @before.delete(id)]
    end

    # Passing ones are written too: they tell that tests ran, which the order of a bisect leaves out
    def record_unnamed(result, label)
      return ResultFile.append(@path, unnamed: label, passed: true) if result.passed? || result.skipped?

      ResultFile.append(@path, unnamed: label, error: error_message(result.failure))
    end

    # An unexpected exception carries its backtrace in the message, which would
    # split identical errors into separate groups
    def error_message(failure)
      case failure
      when nil then nil
      when Minitest::UnexpectedError then "#{failure.error.class}: #{failure.error.message}"
      else failure.message
      end
    end
  end
end
