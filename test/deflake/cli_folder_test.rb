# frozen_string_literal: true

require_relative "folder_cases"

module Deflake
  # A folder given as the test path: every test file in it, however deep, is checked
  class CLIFolderTest < Minitest::Test
    include FolderCases

    def test_checks_every_test_file_in_nested_folders
      write_nested
      status, out, err = run_cli(@folder, "--runs", "1")

      assert_equal 0, status
      assert_equal <<~TEXT, out
        == #{@folder}/a/b/nested_spec.rb (1 of 2)
        Nested passes: failed 0 of 1 runs (0%)

        == #{@folder}/models/user_test.rb (2 of 2)
        UserTest#test_passes: failed 0 of 1 runs (0%)
      TEXT
      assert_includes err, "deflake: checked 2 files, nothing found"
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
      assert_includes err, "deflake: checked 3 files\nfailing or leaking tests in:\n  #{@folder}/fails_test.rb\n" \
                           "could not check:\n  #{@folder}/broken_test.rb\n"
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
  end
end
