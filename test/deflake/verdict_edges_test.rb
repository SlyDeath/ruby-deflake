# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Deflake
  # Verdicts, bisect and finding tests by line where a careless answer would mislead
  class VerdictEdgesTest < Minitest::Test
    def test_bisect_tells_a_test_that_fails_alone_with_the_seed
      bisect = Bisect.new(fixture("seeded.rb"), seed: 2, adapter: Adapters::Minitest)

      assert_empty bisect.call("SeededTest#test_victim")
      assert_predicate bisect, :alone?
    end

    def test_a_failure_that_never_happens_again_is_random_without_culprits
      Dir.mktmpdir do |dir|
        ENV["DEFLAKE_FIXTURE_ONCE"] = File.join(dir, "once")
        diagnosis = Investigation.new(fixture("once.rb"), runs: 1).call.find do |item|
          item.id == "OnceTest#test_victim"
        end

        assert_equal :random, diagnosis.verdict
        refute_predicate diagnosis.culprits, :found?
      ensure
        ENV.delete("DEFLAKE_FIXTURE_ONCE")
      end
    end

    def test_a_test_that_fails_alone_still_gets_a_bisect_for_errors_it_never_had_alone
      file = Summary.new([Run.new(seed: 5, passed: false, error: "polluted"),
                          Run.new(seed: 6, passed: false, error: "own")])
      alone = Summary.new([Run.new(seed: 7, passed: false, error: "own")])
      diagnosis = Diagnosis.new(name: "t", id: "t", file_runs: file, isolated_runs: alone, culprits: nil)

      assert_equal [5], Investigation.new("x.rb", runs: 1, adapter: Adapters::Minitest).send(:bisect_seeds, diagnosis)
    end

    # A random test fails with other numbers every time: that is the same error, not a new one
    def test_errors_that_differ_only_in_numbers_are_no_reason_for_a_bisect
      file = Summary.new([Run.new(seed: 5, passed: false, error: "Expected |93.77 - 100| (6.22) to be <= 5.")])
      alone = Summary.new([Run.new(seed: 7, passed: false, error: "Expected |105.12 - 100| (5.12) to be <= 5.")])
      diagnosis = Diagnosis.new(name: "t", id: "t", file_runs: file, isolated_runs: alone, culprits: nil)

      assert_empty Investigation.new("x.rb", runs: 1, adapter: Adapters::Minitest).send(:bisect_seeds, diagnosis)
    end

    def test_bisect_tries_the_first_seed_of_every_error_first
      errors = { "timeout" => [1, 2], "polluted" => [3, 4] }

      assert_equal [1, 3, 2], Investigation.new("x.rb", runs: 1, adapter: Adapters::Minitest).send(:seeds_of, errors)
    end

    def test_replaying_an_order_seeds_random_numbers_as_a_whole_run_does
      path = fixture("random_numbers.rb")
      whole = Execution.call(Adapters::Minitest, path, seed: 11).to_h { |row| [row["id"], row["error"]] }
      replay = Adapters::Minitest.run_in_order(path, ["SecondRandomTest#test_draws"], seed: 11)

      assert_equal whole["SecondRandomTest#test_draws"], replay.first["error"]
    end

    def test_rspec_runs_every_example_in_order_despite_fail_fast
      ids = ["./test/fixtures/fail_fast_order_spec.rb[1:1]", "./test/fixtures/fail_fast_order_spec.rb[1:2]"]
      rows = Adapters::RSpec.run_in_order(fixture("fail_fast_order_spec.rb"), ids, seed: 1)

      assert_equal([false, true], ids.map { |id| rows.find { |row| row["id"] == id }&.fetch("passed") })
    end

    # Examples of another file come in with require_relative, and only those asked for run
    def test_rspec_runs_in_order_only_the_examples_asked_for_from_any_file
      ids = ["./test/fixtures/required_examples_spec.rb[1:1]"]
      rows = Adapters::RSpec.run_in_order(fixture("required_examples_spec.rb"), ids, seed: 1)

      assert_equal(ids, rows.filter_map { |row| row["id"] })
      assert(rows.all? { |row| row["passed"] })
    end

    def test_rspec_focus_lists_examples_without_running_them
      ids = Adapters::RSpec.focus(fixture("focus_fail_fast_spec.rb"), 6)

      assert_equal 3, ids.size
    end

    def test_focuses_on_a_test_a_macro_defines
      assert_equal ["PagesTest#test_admin_requires_login"], Adapters::Minitest.focus(fixture("macro.rb"), 13)
      assert_equal ["PagesTest#test_home_renders"], Adapters::Minitest.focus(fixture("macro.rb"), 10)
    end

    def test_refuses_a_line_in_a_class_without_a_name
      error = assert_raises(Error) { Adapters::Minitest.focus(fixture("anonymous_and_named.rb"), anonymous_line) }

      assert_includes error.message, "class without a name"
    end

    def test_sends_a_spec_that_requires_a_minitest_helper_to_minitest
      Dir.mktmpdir do |dir|
        path = File.join(dir, "thing_spec.rb")
        File.write(path, "require \"minitest_helper\"\n\ndescribe Thing do\n  it { _(1).must_equal 1 }\nend\n")

        assert_equal Adapters::Minitest, Adapters.for(path)
      end
    end

    def test_keeps_only_the_project_options_of_spec_opts
      words = %w[--require support --seed 5 --order=defined -f json --tag fast --fail-fast]

      assert_equal %w[--require support --tag fast], Adapters::RSpec.project_options(words)
    end

    def test_names_the_group_of_an_rspec_example
      assert_equal "./a_spec.rb[1:2]", Adapters::RSpec.group("./a_spec.rb[1:2:3]")
      assert_equal "Foo", Adapters::Minitest.group("Foo#test_bar")
    end

    private

    def anonymous_line
      File.readlines(fixture("anonymous_and_named.rb")).index { |line| line.include?("def test_") } + 2
    end

    def fixture(name)
      File.expand_path("../fixtures/#{name}", __dir__)
    end
  end
end
