# frozen_string_literal: true

require_relative "folder_cases"

module Deflake
  # A folder given as the test path, when things go wrong
  class CLIFolderEdgesTest < Minitest::Test
    include FolderCases

    # Raises Interrupt as Ctrl-C would once this many files were investigated
    module Interrupting
      class << self
        attr_accessor :after, :count
      end

      def call
        if Interrupting.after
          Interrupting.count = Interrupting.count.to_i + 1
          raise Interrupt if Interrupting.count > Interrupting.after
        end
        super
      end
    end
    Investigation.prepend(Interrupting)

    def test_lists_a_file_that_could_not_run_in_json_and_shows_progress_on_stderr
      write("broken_test.rb", "require 'missing_helper'")
      write("passes_test.rb", format(PASSES, name: "PassesTest"))
      _, out, err = run_cli(@folder, "--runs", "1", "--format", "json")

      broken = JSON.parse(out).find { |test| test["file"] == "#{@folder}/broken_test.rb" }

      assert_equal "not_checked", broken["verdict"]
      assert_includes broken["errors"].first["message"], "missing_helper"
      assert_includes err, "deflake: checking #{@folder}/passes_test.rb (2 of 2)"
    end

    def test_names_the_file_whose_tests_all_skipped_themselves
      write("skips_test.rb", SKIPS)
      _, _, err = run_cli(@folder, "--runs", "1")

      assert_includes err, "every test of #{@folder}/skips_test.rb skipped itself"
    end

    def test_leaves_out_installed_gems_and_packages
      write("vendor/bundle/gem_test.rb", FAILS)
      write("node_modules/pkg/pkg_spec.rb", SPEC)
      write("passes_test.rb", format(PASSES, name: "PassesTest"))

      assert_equal 0, run_cli(@folder, "--runs", "1").first
    end

    def test_stops_when_the_reader_is_gone
      write_mixed
      out = Object.new
      def out.puts(*) = raise(Errno::EPIPE)
      err = StringIO.new

      assert_equal 2, CLI.new([@folder, "--runs", "1"], out: out, err: err).run
      assert_includes err.string, "deflake: checked 1 of 3 files"
      refute_includes err.string, "unexpected error"
    end

    def test_reports_the_files_checked_before_an_interrupt
      write_mixed
      Interrupting.after = 2
      status, _, err = run_cli(@folder, "--runs", "1")

      assert_equal 130, status
      assert_includes err, "deflake: checked 2 of 3 files\nfailing or leaking tests in:\n  #{@folder}/fails_test.rb\n"
    ensure
      Interrupting.after = Interrupting.count = nil
    end

    def test_takes_a_folder_whose_name_ends_in_a_line_number
      write("a:5/passes_test.rb", format(PASSES, name: "PassesTest"))

      assert_equal 0, run_cli(File.join(@folder, "a:5"), "--runs", "1").first
    end
  end
end
