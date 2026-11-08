# frozen_string_literal: true

require "test_helper"
require "stringio"

module Deflake
  class TextReportTest < Minitest::Test
    def test_shows_a_rare_failure_as_less_than_one_percent
      assert_includes report(diagnosis("A", runs(1, of: 250))), "A: failed 1 of 250 runs (<1%)"
      assert_includes report(diagnosis("A", runs(249, of: 250))), "A: failed 249 of 250 runs (>99%)"
    end

    def test_tells_tests_with_the_same_name_apart_by_id
      out = report(diagnosis("Same", runs(0, of: 1), id: "./a_spec.rb[1:1]"),
                   diagnosis("Same", runs(0, of: 1), id: "./a_spec.rb[1:2]"))

      assert_equal "Same (./a_spec.rb[1:1]): failed 0 of 1 runs (0%)\n" \
                   "Same (./a_spec.rb[1:2]): failed 0 of 1 runs (0%)\n", out
    end

    def test_shows_a_test_that_skipped_itself_every_time
      summary = Summary.new([], id: "A", skipped: 3, skipped_leaks: ["$a was set"] * 3)

      assert_equal "A: skipped in all 3 runs\n  leaks: $a was set (3 of 3 runs)\n", report(diagnosis("A", summary))
    end

    private

    def runs(failures, of:)
      Summary.new(Array.new(of) { |index| Run.new(seed: index, passed: index >= failures, error: "boom") })
    end

    def diagnosis(name, summary, id: name)
      isolated = summary.failures.zero? ? nil : summary
      Diagnosis.new(name: name, id: id, file_runs: summary, isolated_runs: isolated, culprits: nil)
    end

    def report(*diagnoses)
      out = StringIO.new
      TextReport.new(out).print(diagnoses)
      out.string
    end
  end
end
