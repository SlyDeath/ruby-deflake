# frozen_string_literal: true

require "test_helper"
require "stringio"
require "English"
require "json"

module Deflake
  class CLITest < Minitest::Test
    def test_version_prints_version_and_exits_zero
      status, out, = run_cli("--version")

      assert_equal 0, status
      assert_equal "deflake #{VERSION}\n", out
    end

    def test_help_prints_usage
      status, out, = run_cli("--help")

      assert_equal 0, status
      assert_includes out, "Usage: deflake"
    end

    def test_unknown_option_exits_with_usage_error
      status, out, err = run_cli("--nope")

      assert_equal 2, status
      assert_empty out
      assert_includes err, "invalid option: --nope"
    end

    def test_executable_runs_as_a_separate_process
      exe = File.expand_path("../../exe/deflake", __dir__)
      lib = File.expand_path("../../lib", __dir__)

      output = IO.popen([RbConfig.ruby, "-I", lib, exe, "--version"], &:read)

      assert_predicate $CHILD_STATUS, :success?
      assert_equal "deflake #{VERSION}\n", output
    end

    def test_runs_file_and_reports_every_test
      sample = File.expand_path("../fixtures/sample.rb", __dir__)

      status, out, = run_cli(sample, "--runs", "2")

      assert_equal 1, status
      assert_includes out, "SampleTest#test_fails: failed 2 of 2 runs"
      assert_includes out, "SampleTest#test_passes: failed 0 of 2 runs"
    end

    def test_explains_why_tests_could_not_run
      broken = File.expand_path("../fixtures/broken.rb", __dir__)

      status, _, err = run_cli(broken, "--runs", "1")

      assert_equal 2, status
      assert_includes err, "cannot load such file -- missing_helper"
    end

    def test_prints_json_report
      status, out, = run_cli(fixture("sample.rb"), "--runs", "1", "--format", "json")

      verdicts = JSON.parse(out).to_h { |test| [test["name"], test["verdict"]] }

      assert_equal 1, status
      assert_equal({ "SampleTest#test_fails" => "fails_on_its_own", "SampleTest#test_passes" => "stable",
                     "SampleTest#test_raises" => "fails_on_its_own" }, verdicts)
    end

    def test_looks_only_at_the_minitest_on_the_given_line
      status, out, = run_cli("#{fixture("sample.rb")}:8", "--runs", "1")

      assert_equal 0, status
      assert_equal "SampleTest#test_passes: failed 0 of 1 runs (0%)\n", out
    end

    def test_looks_only_at_the_example_on_the_given_line
      _, out, = run_cli("#{fixture("sample_spec.rb")}:9", "--runs", "1")

      assert_match(/\ASample fails: failed 1 of 1 runs/, out)
      refute_includes out, "Sample passes"
    end

    def test_complains_when_there_is_no_test_on_the_line
      status, _, err = run_cli("#{fixture("sample.rb")}:2", "--runs", "1")

      assert_equal 2, status
      assert_includes err, "no test found at"
    end

    # Like a plain run, which exits 0 when every test skipped itself
    def test_exits_zero_when_every_test_skipped_itself
      status, out, err = run_cli(fixture("all_skipped.rb"), "--runs", "1")

      assert_equal 0, status
      assert_empty out
      assert_includes err, "every test skipped itself"
    end

    def test_looks_only_at_the_test_on_the_line_in_its_own_class
      status, out, = run_cli("#{fixture("focus.rb")}:7", "--runs", "1")

      assert_equal 0, status
      assert_equal "AdminTest#test_create: failed 0 of 1 runs (0%)\n", out
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
