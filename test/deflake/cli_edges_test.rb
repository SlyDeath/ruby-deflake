# frozen_string_literal: true

require "test_helper"
require "stringio"
require "open3"
require "tmpdir"

module Deflake
  # Arguments and situations at the edges of the command line
  class CLIEdgesTest < Minitest::Test
    def test_takes_an_empty_test_path_as_a_missing_one
      status, _, err = run_cli("")

      assert_equal 2, status
      assert_includes err, "missing argument: TEST_PATH"
    end

    def test_takes_a_file_whose_name_ends_in_a_line_number_as_a_whole
      Dir.mktmpdir do |dir|
        path = File.join(dir, "sample.rb:7")
        FileUtils.cp(fixture("sample.rb"), path)

        status, out, = run_cli(path, "--runs", "1")

        assert_equal 1, status
        assert_includes out, "SampleTest#test_fails"
      end
    end

    def test_reads_numbers_as_decimal
      status, out, = run_cli(fixture("all_skipped.rb"), "--runs", "010", "--format", "json")

      assert_equal 0, status
      assert_empty JSON.parse(out)
      assert_equal 2, run_cli(fixture("sample.rb"), "--runs", "0x10").first
    end

    def test_says_no_test_found_for_an_rspec_line_without_an_example
      status, _, err = run_cli("#{fixture("order_spec.rb")}:1", "--runs", "1")

      assert_equal 2, status
      assert_includes err, "no test found at"
    end

    def test_says_the_test_on_the_line_skipped_itself
      status, _, err = run_cli("#{fixture("sample.rb")}:#{skip_line}", "--runs", "1")

      assert_equal 0, status
      assert_includes err, "the test at line #{skip_line} skipped itself in every run"
    end

    def test_says_the_test_on_the_line_never_ran
      status, _, err = run_cli("#{fixture("exit_first.rb")}:13", "--runs", "1")

      assert_equal 1, status
      assert_includes err, "ExitFirstTest#test_b_never_runs never ran"
      refute_includes err, "skipped itself"
    end

    # The first process to run hooks breaks before its tests. The probe for the line runs none,
    # so the first run of the file is the one that breaks
    def test_finds_the_line_without_running_hooks
      status, out, = run_cli("#{fixture("suite_once_spec.rb")}:19", "--runs", "2")

      assert_equal 1, status
      assert_includes out, "Suite passes: failed 0 of 1 runs"
      assert_includes out, "database not ready"
    ensure
      FileUtils.rm_f(File.join(Dir.tmpdir, "deflake-fixture-suite-#{Process.pid}"))
    end

    def test_stops_the_test_processes_when_interrupted
      Dir.mktmpdir do |dir|
        Open3.popen3({ "DEFLAKE_FIXTURE_PIDS" => dir }, *deflake, fixture("hang.rb")) do |_, _, err, wait|
          child = wait_for_child(dir)
          Process.kill("INT", wait.pid)

          # Ended by the interrupt itself, as a shell loop around deflake expects
          assert_equal Signal.list["INT"], wait.value.termsig
          # Last, with no backtrace of the interrupt after it
          assert_match(/deflake: interrupted\n\z/, err.read)
          assert gone?(child), "the test process is still running"
        end
      end
    end

    private

    def wait_for_child(dir)
      200.times do
        pid = Dir.children(dir).first
        return pid.to_i if pid

        sleep 0.05
      end

      flunk "the test process did not start"
    end

    def deflake
      [RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), File.expand_path("../../exe/deflake", __dir__)]
    end

    # A killed process can linger for a moment before it is reaped
    def gone?(pid)
      40.times do
        Process.kill(0, pid)
        sleep 0.05
      end
      false
    rescue Errno::ESRCH
      true
    end

    def skip_line
      File.readlines(fixture("sample.rb")).index { |line| line.include?("def test_skipped") } + 1
    end

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
