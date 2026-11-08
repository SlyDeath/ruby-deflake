# frozen_string_literal: true

require "test_helper"
require "stringio"
require "open3"

module Deflake
  # Usage errors and tests that cannot run: always exit code 2, never a Ruby backtrace
  class CLIErrorsTest < Minitest::Test
    def test_shows_the_output_of_tests_that_could_not_run_once_and_without_ruby_internals
      exe = File.expand_path("../../exe/deflake", __dir__)
      lib = File.expand_path("../../lib", __dir__)

      _, err, status = Open3.capture3(RbConfig.ruby, "-I", lib, exe, fixture("broken.rb"), "--runs", "2", "--jobs", "2")

      assert_equal 2, status.exitstatus
      assert_equal 1, err.scan("cannot load such file -- missing_helper (LoadError)").size
      refute_includes err, "terminated with exception"
    end

    def test_rejects_runs_and_jobs_below_one
      [%w[--runs 0], %w[--runs -1], %w[--jobs 0], %w[--jobs -1]].each do |option|
        status, _, err = run_cli(fixture("sample.rb"), *option)

        assert_equal 2, status, option.join(" ")
        assert_includes err, "must be 1 or more"
      end
    end

    def test_complains_without_a_test_path
      status, out, err = run_cli("--format", "json")

      assert_equal 2, status
      assert_empty out
      assert_includes err, "missing argument: TEST_PATH"
    end

    def test_takes_one_test_path_at_a_time
      status, _, err = run_cli(fixture("sample.rb"), fixture("order.rb"))

      assert_equal 2, status
      assert_includes err, "one TEST_PATH at a time"
    end

    def test_complains_about_a_missing_file
      ["missing_test.rb", "missing_test.rb:5", "#{File.dirname(fixture("sample.rb"))}:5"].each do |path|
        status, _, err = run_cli(path, "--runs", "1")

        assert_equal 2, status, path
        assert_includes err, "deflake: no such file"
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
