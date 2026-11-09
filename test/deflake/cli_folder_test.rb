# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"
require "json"

module Deflake
  # A folder given as the test path: every test file in it, however deep, is checked
  class CLIFolderTest < Minitest::Test
    PASSES = <<~RUBY
      require "minitest/autorun"

      class %<name>s < Minitest::Test
        def test_passes = assert(true)
      end
    RUBY
    FAILS = <<~RUBY
      require "minitest/autorun"

      class FailsTest < Minitest::Test
        def test_fails = assert_equal(2, 1)
      end
    RUBY
    SPEC = <<~RUBY
      RSpec.describe "Nested" do
        it("passes") { expect(1).to eq(1) }
      end
    RUBY

    # Fixtures named *_test.rb would run with the suite itself, so they are written here
    def setup
      @folder = Dir.mktmpdir("deflake-folder")
    end

    def teardown
      FileUtils.remove_entry(@folder)
    end

    def test_checks_every_test_file_in_nested_folders
      write_nested
      status, out, err = run_cli(@folder, "--runs", "1")

      assert_equal 0, status
      assert_equal <<~TEXT, out
        == #{@folder}/a/b/nested_spec.rb
        Nested passes: failed 0 of 1 runs (0%)

        == #{@folder}/models/user_test.rb
        UserTest#test_passes: failed 0 of 1 runs (0%)
      TEXT
      assert_includes err, "deflake: checked 2 files; nothing found"
    end

    def test_goes_on_after_a_file_that_cannot_run
      write_mixed
      status, out, err = run_cli(@folder, "--runs", "1")

      assert_equal 2, status
      assert_includes out, "PassesTest#test_passes: failed 0 of 1 runs"
      assert_includes err, "cannot load such file -- missing_helper"
    end

    def test_names_the_files_to_look_at
      write_mixed
      _, out, err = run_cli(@folder, "--runs", "1")

      assert_includes out, "FailsTest#test_fails: failed 1 of 1 runs"
      assert_includes err, "failing or leaking tests in #{@folder}/fails_test.rb; " \
                           "could not check #{@folder}/broken_test.rb"
    end

    def test_exits_one_when_a_test_fails
      write("fails_test.rb", FAILS)
      write("passes_test.rb", format(PASSES, name: "PassesTest"))

      assert_equal 1, run_cli(@folder, "--runs", "1").first
    end

    def test_prints_one_json_array_with_the_file_of_every_test
      write("fails_test.rb", FAILS)
      write("sub/passes_test.rb", format(PASSES, name: "PassesTest"))

      _, out, = run_cli(@folder, "--runs", "1", "--format", "json")

      files = JSON.parse(out).to_h { |test| [test["name"], test["file"]] }

      assert_equal({ "FailsTest#test_fails" => "#{@folder}/fails_test.rb",
                     "PassesTest#test_passes" => "#{@folder}/sub/passes_test.rb" }, files)
    end

    def test_complains_about_a_folder_without_test_files
      write("helper.rb", "")

      status, _, err = run_cli(@folder)

      assert_equal 2, status
      assert_includes err, "no test files (*_test.rb or *_spec.rb) in #{@folder}"
    end

    def test_refuses_a_line_in_a_folder
      write("passes_test.rb", format(PASSES, name: "PassesTest"))

      status, _, err = run_cli("#{@folder}:3")

      assert_equal 2, status
      assert_includes err, "is a folder: a line number needs a test file"
    end

    private

    def write_nested
      write("models/user_test.rb", format(PASSES, name: "UserTest"))
      write("a/b/nested_spec.rb", SPEC)
      write("support/helper.rb", "raise 'not a test file'")
    end

    def write_mixed
      write("broken_test.rb", "require 'missing_helper'")
      write("fails_test.rb", FAILS)
      write("passes_test.rb", format(PASSES, name: "PassesTest"))
    end

    def write(name, source)
      path = File.join(@folder, name)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, source)
    end

    def run_cli(*argv)
      out = StringIO.new
      err = StringIO.new
      status = CLI.new(argv, out: out, err: err).run
      [status, out.string, err.string]
    end
  end
end
