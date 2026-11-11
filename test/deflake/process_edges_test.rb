# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"

module Deflake
  # Test processes in hard situations: hooks, odd exceptions, the terminal
  class ProcessEdgesTest < Minitest::Test
    def test_a_test_whose_runs_alone_report_only_a_hook_failure_could_not_run_alone
      diagnoses = Investigation.new(fixture("hook_breaks_alone.rb"), runs: 2).call

      assert_equal([[:failed, "BreaksAloneTest#test_fails"]], diagnoses.map { |item| [item.verdict, item.id] })
    end

    def test_pending_examples_do_not_hide_or_split_an_error_outside_of_examples
      outside = Runner.new(fixture("pending_outside_spec.rb"), runs: 3).call.fetch(Execution::OUTSIDE)

      assert_equal 1, outside.errors.size
      assert_includes outside.errors.keys.first, "hook boom"
    end

    def test_an_error_outside_of_examples_counts_even_when_an_example_failed
      outside = Runner.new(fixture("outside_and_failure_spec.rb"), runs: 1).call.fetch(Execution::OUTSIDE)

      assert_equal 1, outside.failures
      assert_includes outside.errors.keys.first, "after(:context)"
    end

    def test_an_exception_with_a_nil_message_does_not_fail_its_neighbours
      rows = Execution.whole_file(Adapters::RSpec, fixture("nil_message_spec.rb"), seed: 1)
      results = rows.to_h { |row| [row["name"], row["passed"]] }

      assert_equal({ "Silent raises" => false, "Silent passes" => true }, results.except("errors outside of tests"))
      assert_includes rows.find { |row| row["name"] == "Silent raises" }["error"], "SilentError"
    end

    def test_a_test_process_has_a_session_of_its_own_and_no_variables_meant_for_deflake
      # As in a test that starts deflake itself
      ENV[ResultFile::ONLY_KEY] = ENV[ResultFile::LIST_KEY] = "outer"
      rows = Execution.whole_file(Adapters::Minitest, fixture("own_session.rb"), seed: 1)

      failures = rows.reject { |row| row["passed"] }.map { |row| row["error"] }

      assert_empty failures
    ensure
      ENV.delete(ResultFile::ONLY_KEY)
      ENV.delete(ResultFile::LIST_KEY)
    end

    def test_a_file_whose_tests_are_all_in_anonymous_classes_and_pass_is_clean
      status, = run_cli(fixture("anonymous_only.rb"), "--runs", "2")

      assert_equal 0, status
    end

    def test_counting_rows_leaves_the_query_cache_alone
      summary = Runner.new(fixture("rails_query_cache.rb"),
                           runs: 1).call.fetch("QueryCacheTest#test_counts_with_one_query")

      assert_equal 0, summary.failures, summary.errors.keys.join("\n")
    end

    def test_counting_rows_is_not_a_query_of_the_test
      summary = Runner.new(fixture("rails_fixture_queries.rb"),
                           runs: 1).call.fetch("FixtureQueriesTest#test_cached_fixtures_make_no_queries")

      assert_equal 0, summary.failures, summary.errors.keys.join("\n")
    end

    def test_leaks_of_a_class_level_hook_show_up_outside_of_tests
      outside = Runner.new(fixture("class_leak.rb"), runs: 1).call.fetch(Execution::OUTSIDE)

      assert_equal ["ClassLeakTest, outside its tests: $connection was set"], outside.leaks.keys
    end

    def test_leaks_of_a_before_context_hook_show_up_outside_of_examples
      outside = Runner.new(fixture("context_leak_spec.rb"), runs: 1).call.fetch(Execution::OUTSIDE)

      assert_equal ["Context, outside its examples: $context_connection was set"], outside.leaks.keys
    end

    def test_a_long_backtrace_keeps_its_message_in_the_tail
      output = "boot.rb:2:in 'deep': database is locked (RuntimeError)\n#{"\tfrom boot.rb:2:in 'deep'\n" * 40}"

      assert_includes Execution.with_tail("broke", output), "database is locked"
    end

    def test_the_tail_drops_progress_dots_counts_and_seeds_inside_lines
      first = "..note from a\nStarted with run options --seed 41234\n3 runs, 3 assertions, 0 failures\nboom\n"
      second = ".note from a\nStarted with run options --seed 9\n4 runs, 5 assertions, 1 failures\nboom\n"

      assert_equal Execution.with_tail("broke", first), Execution.with_tail("broke", second)
    end

    def test_reads_only_the_end_of_a_huge_output
      Dir.mktmpdir do |dir|
        log = File.join(dir, "output.log")
        File.write(log, "#{"x" * 100}\n" * 10_000)

        assert_operator Tail.read(log).bytesize, :<=, Tail::KEEP
      end
    end

    private

    def fixture(name)
      File.expand_path("../fixtures/#{name}", __dir__)
    end

    def run_cli(*argv)
      out = StringIO.new
      err = StringIO.new
      status = CLI.new(argv, out: out, err: err).run
      [status, out.string, err.string]
    end
  end
end
