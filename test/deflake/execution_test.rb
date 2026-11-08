# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Deflake
  # How one test process is run and what its results say
  class ExecutionTest < Minitest::Test
    FIXTURES = File.expand_path("../fixtures", __dir__)

    def test_runs_a_test_whose_name_is_not_ascii_alone_whatever_the_locale
      rows = Execution.some(Adapters::Minitest, fixture("unicode.rb"), seed: 1, only: "UnicodeTest#test_проверка",
                                                                       env: { "LC_ALL" => "C", "LANG" => "C" })

      assert_equal([["UnicodeTest#test_проверка", true]], rows.map { |row| [row["id"], row["passed"]] })
    end

    def test_tells_what_a_process_that_broke_before_its_first_test_printed
      rows = Execution.whole_file(Adapters::RSpec, fixture("suite_once_spec.rb"), seed: 1)

      assert_equal([[Execution::OUTSIDE, false]], rows.map { |row| [row["id"], row["passed"]] })
      assert_includes rows.first["error"], "before any test finished"
      assert_includes rows.first["error"], "database not ready"
    ensure
      FileUtils.rm_f(File.join(Dir.tmpdir, "deflake-fixture-suite-#{Process.pid}"))
    end

    def test_tells_what_failed_outside_of_tests
      rows = Execution.whole_file(Adapters::RSpec, fixture("outside_spec.rb"), seed: 1)

      assert_includes rows.last["error"], "cleanup failed"
    end

    def test_tells_about_a_failing_test_in_a_class_without_a_name
      outside = Execution.whole_file(Adapters::Minitest, fixture("anonymous_failing.rb"), seed: 1).last

      assert_equal [Execution::OUTSIDE, false], [outside["id"], outside["passed"]]
      assert_includes outside["error"], "test_in_anonymous_class (in a class without a name): failed in an anonymous"
    end

    def test_does_not_wait_for_processes_the_tests_started
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rows = Execution.call(Adapters::Minitest, fixture("background.rb"), seed: 1)

      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 4
      assert(rows.all? { |row| row["passed"] })
    end

    # Long enough for Ruby to boot and start the test on a busy machine
    def test_stops_a_test_process_that_runs_longer_than_the_timeout
      Execution.timeout = 5
      rows = Execution.whole_file(Adapters::Minitest, fixture("hang.rb"), seed: 1)
      hang = rows.find { |row| row["id"] == "HangTest#test_hangs" } or flunk "no row for the test: #{rows.inspect}"

      assert_match(/\Athe test process timed out after 5 seconds during this test/, hang["error"])
    ensure
      Execution.timeout = nil
    end

    def test_says_a_process_timed_out_before_its_first_test
      Execution.timeout = 1
      error = assert_raises(Execution::NoResults) { Execution.call(Adapters::Minitest, fixture("slow_boot.rb"), seed: 1) }

      assert_includes error.message, "(the test process timed out after 1 seconds)"
    ensure
      Execution.timeout = nil
    end

    # The progress dots and the seed change from run to run, the error itself does not
    def test_one_error_outside_of_tests_is_one_group_and_keeps_its_text
      outside = Runner.new(fixture("context_error_spec.rb"), runs: 6).call.fetch(Execution::OUTSIDE)

      assert_equal 1, outside.errors.size
      assert_includes outside.errors.keys.first, "could not seed the database after 5 seconds"
    end

    def test_tells_about_a_failure_in_a_class_without_a_name_next_to_a_failing_named_test
      outside = Execution.whole_file(Adapters::Minitest, fixture("anonymous_and_named.rb"), seed: 1).last

      assert_equal [Execution::OUTSIDE, false], [outside["id"], outside["passed"]]
      assert_includes outside["error"], "test_in_anonymous_class (in a class without a name): failed in an anonymous"
    end

    private

    def fixture(name)
      File.join(FIXTURES, name)
    end
  end
end
