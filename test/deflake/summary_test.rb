# frozen_string_literal: true

require "test_helper"

module Deflake
  class SummaryTest < Minitest::Test
    def test_counts_failures_among_all_runs
      runs = [
        Run.new(seed: 101, passed: true, error: nil),
        Run.new(seed: 202, passed: false, error: "Expected: 2\n  Actual: 1"),
        Run.new(seed: 303, passed: true, error: nil)
      ]

      summary = Summary.new(runs)

      assert_equal 3, summary.total
      assert_equal 1, summary.failures
      assert_in_delta 0.333, summary.failure_rate, 0.001
    end

    def test_groups_failed_seeds_by_error_message
      mismatch = "Expected: 2\n  Actual: 1"
      runs = [
        Run.new(seed: 1, passed: false, error: mismatch),
        Run.new(seed: 2, passed: true, error: nil),
        Run.new(seed: 3, passed: false, error: "Net::ReadTimeout"),
        Run.new(seed: 4, passed: false, error: mismatch)
      ]

      summary = Summary.new(runs)

      assert_equal({ mismatch => [1, 4], "Net::ReadTimeout" => [3] }, summary.errors)
    end

    # Object addresses change in every process
    def test_groups_errors_that_differ_only_in_object_addresses
      runs = [Run.new(seed: 1, passed: false, error: "Expected #<Object:0x00007f4235c7a370> to be nil."),
              Run.new(seed: 2, passed: false, error: "Expected #<Object:0x00007f094669b9e0> to be nil.")]

      assert_equal({ "Expected #<Object:0x...> to be nil." => [1, 2] }, Summary.new(runs).errors)
    end

    def test_counts_leaks_of_skipped_runs_and_has_no_rate_without_runs
      summary = Summary.new([], skipped: 2, skipped_leaks: ["$a was set"])

      assert_equal [0, 0.0, 2], [summary.total, summary.failure_rate, summary.skipped]
      assert_equal({ "$a was set" => 1 }, summary.leaks)
    end
  end
end
