# frozen_string_literal: true

require "test_helper"
require "stringio"

module Deflake
  # Reports and the command line on unusual input
  class ReportEdgesTest < Minitest::Test
    def test_text_report_says_runs_where_the_test_skipped_itself
      summary = Summary.new([Run.new(seed: 1, passed: true, error: nil)], id: "t", name: "t", skipped: 2)
      diagnosis = Diagnosis.new(name: "t", id: "t", file_runs: summary, isolated_runs: nil, culprits: nil)
      out = StringIO.new
      TextReport.new(out).print([diagnosis], shared: ["t"])

      assert_equal "t (t): failed 0 of 1 runs (0%), skipped in 2 more\n", out.string
    end

    def test_json_report_lists_a_test_that_never_ran_and_survives_odd_bytes
      out = StringIO.new
      JsonReport.new(out).print([], not_run: ["A#test_\xC3".b])

      assert_equal "not_run", JSON.parse(out.string).first["verdict"]
    end

    def test_takes_a_path_with_a_newline_as_a_missing_file
      err = StringIO.new

      assert_equal 2, CLI.new(["no\nsuch.rb"], out: StringIO.new, err: err).run
      assert_includes err.string, "no such file"
    end

    def test_says_that_a_folder_is_not_a_test_file
      err = StringIO.new

      assert_equal 2, CLI.new([File.expand_path("../fixtures", __dir__)], out: StringIO.new, err: err).run
      assert_includes err.string, "is a folder: deflake checks one test file at a time"
    end

    def test_a_reader_that_stops_early_is_not_an_error
      out = Object.new
      def out.puts(*) = raise(Errno::EPIPE)
      code = CLI.new([File.expand_path("../fixtures/sample.rb", __dir__), "--runs", "1"], out: out,
                                                                                          err: StringIO.new).run

      assert_equal 1, code
    end
  end
end
