# frozen_string_literal: true

require "test_helper"

module Deflake
  class MinitestAdapterTest < Minitest::Test
    # Not on the command line, where a name that is not ASCII would follow the locale
    def test_passes_the_test_to_run_in_the_environment_as_ascii
      env = Adapters::Minitest.env("A#test_café")

      assert_predicate env[ResultFile::ONLY_KEY], :ascii_only?
      assert_equal ["A#test_café"], ResultFile.unpack_ids(env[ResultFile::ONLY_KEY])
      refute_includes Adapters::Minitest.command("x.rb", seed: 1, only: "A#test_café"), "--name"
    end

    def test_focuses_on_the_test_defined_above_a_line
      focus = Adapters::Minitest.focus(fixture("sample.rb"), 9)

      assert_equal ["SampleTest#test_passes"], focus
    end

    # Found by where Minitest says each test is defined, not by parsing the file
    def test_focuses_on_the_test_of_its_own_class
      assert_equal ["AdminTest#test_create"], focused(7)
    end

    def test_focuses_on_a_spec
      assert_equal ["SpecStyle#test_0001_works with café"], focused(14)
    end

    def test_focuses_on_rails_style_tests_with_quotes_and_interpolation
      assert_equal ['FocusTest#test_renders_"Save"_button'], focused(22)
      assert_equal %w[FocusTest#test_renders_large_widget FocusTest#test_renders_small_widget], focused(27)
    end

    def test_focuses_on_a_test_with_a_non_ascii_name
      assert_equal ["FocusTest#test_café"], focused(32)
    end

    def test_complains_about_a_line_above_every_test
      error = assert_raises(Error) { Adapters::Minitest.focus(fixture("sample.rb"), 2) }

      assert_match(/no test found at .*sample\.rb:2\z/, error.message)
    end

    # Rails' parallelize orders tests differently for a seed without PARALLEL_WORKERS=1
    def test_reproduce_command_works_with_rails_parallelize_and_spaces
      assert_equal "PARALLEL_WORKERS=1 MT_CPU=1 ruby -Ilib -Itest test/user\\ flows/a_test.rb --seed 7",
                   Adapters::Minitest.reproduce("test/user flows/a_test.rb", 7)
    end

    private

    def focused(line, path = fixture("focus.rb"))
      Adapters::Minitest.focus(path, line).sort
    end

    def fixture(name)
      File.expand_path("../fixtures/#{name}", __dir__)
    end
  end
end
