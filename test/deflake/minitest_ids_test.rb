# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Deflake
  # How Minitest tests are told apart and run again, alone or in a given order
  class MinitestIdsTest < Minitest::Test
    FIXTURES = File.expand_path("../fixtures", __dir__)

    def test_knows_a_class_by_the_name_it_tells
      summaries = Runner.new(fixture("named_class.rb"), runs: 1).call

      assert_equal({ "DynamicTest#test_passes" => 0, "UnassignedTest#test_passes" => 0 },
                   summaries.transform_values(&:failures))
    end

    def test_tells_apart_classes_with_the_same_name
      summaries = Runner.new(fixture("dup_describe.rb"), runs: 2).call

      assert_equal({ "Cart#test_0001_totals" => [0, 2], "Cart (2)#test_0001_totals" => [2, 2] },
                   summaries.transform_values { |summary| [summary.failures, summary.total] })
    end

    def test_runs_the_second_of_two_classes_with_the_same_name_alone
      rows = Execution.some(Adapters::Minitest, fixture("dup_describe.rb"), seed: 1, only: "Cart (2)#test_0001_totals")

      assert_equal([["Cart (2)#test_0001_totals", false]], rows.map { |row| [row["id"], row["passed"]] })
    end

    # The tests run through Minitest itself, so a hook around a whole class still runs
    def test_finds_the_culprit_when_the_class_has_hooks_around_its_tests
      victim = Investigation.new(fixture("class_hook.rb"), runs: 10).call.find do |d|
        d.name == "HookedTest#test_victim"
      end

      assert_equal :order_dependent, victim.verdict
      assert_equal ["HookedTest#test_pollutes"], victim.culprits.ids
    end

    def test_reports_errors_outside_of_tests_without_running_them_alone
      outside = Investigation.new(fixture("anonymous_failing.rb"), runs: 1).call
                             .find { |diagnosis| diagnosis.id == Execution::OUTSIDE }

      assert_nil outside.isolated_runs
      assert_equal :failed, outside.verdict
    end

    # minitest-hooks reports an error in before_all as a result named before_all, which is no test
    def test_reports_a_failing_class_hook_as_an_error_outside_of_tests
      diagnoses = Investigation.new(fixture("before_all_hook.rb"), runs: 1).call.to_h { |d| [d.id, d] }
      outside = diagnoses.fetch(Execution::OUTSIDE)

      assert_equal %i[stable failed], [diagnoses.fetch("HookTest#test_passes").verdict, outside.verdict]
      assert_includes outside.file_runs.errors.keys.first,
                      "HookTest#before_all (not a test): RuntimeError: before_all broke"
    end

    def test_keeps_the_report_when_no_run_alone_reaches_the_test
      diagnosis = Investigation.new(fixture("breaks_alone.rb"), runs: 1).call.first

      assert_nil diagnosis.isolated_runs
      assert_equal :failed, diagnosis.verdict
    end

    private

    def fixture(name)
      File.join(FIXTURES, name)
    end
  end
end
