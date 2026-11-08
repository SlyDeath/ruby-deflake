# frozen_string_literal: true

require "test_helper"
require "stringio"
require "deflake/minitest_tests"

module Deflake
  # Tests that cannot run by name, files without tests, tests from required files and other
  # cases where runs, reports and adapters can easily mislead
  class RunEdgesTest < Minitest::Test
    # Only there to be in Minitest's list
    class LazyClientTest < Minitest::Test; end

    def test_minitest_gets_its_own_list_of_classes_back_after_running_only_some
      MinitestTests.send(:only_these, [RunEdgesTest])

      assert_equal [RunEdgesTest], Minitest::Runnable.runnables
      assert_includes Minitest::Runnable.runnables, LazyClientTest
    end

    def test_a_file_without_tests_is_a_mistake
      status, _, err = run_cli(fixture("empty_spec.rb"), "--runs", "1")

      assert_equal 2, status
      assert_includes err, "no tests ran"
    end

    def test_a_polluter_in_a_class_without_a_name_makes_the_victim_order_dependent
      diagnosis = Investigation.new(fixture("anonymous_polluter.rb"), runs: 4).call.find do |item|
        item.id == "AnonymousVictimTest#test_victim"
      end

      skip "the class without a name never ran first" if diagnosis.file_runs.failures.zero?

      assert_equal :order_dependent, diagnosis.verdict
      assert diagnosis.culprits.hidden
    end

    def test_the_tail_keeps_the_dot_of_a_relative_path
      assert_equal ["./spec/a_spec.rb:3", "../b.rb:1", "note"], Tail.lines("./spec/a_spec.rb:3\n../b.rb:1\n...note\n")
    end

    def test_a_line_that_requires_a_file_of_tests_has_no_test
      path = fixture("requires_tests.rb")
      line = File.readlines(path).index { |text| text.include?("require_relative") } + 1

      error = assert_raises(Error) { Adapters::Minitest.focus(path, line) }
      assert_includes error.message, "no test"
    end

    def test_a_line_without_examples_has_no_test_even_when_rspec_fails_a_run_without_them
      error = assert_raises(Error) { Adapters::RSpec.focus(fixture("no_examples_fail_spec.rb"), 3) }

      assert_includes error.message, "no test found"
    end

    def test_errors_outside_of_tests_that_only_leaked_do_not_say_failed
      summary = Summary.new([Run.new(seed: 1, passed: true, error: nil, leaks: ["$x was set"])],
                            id: Execution::OUTSIDE, name: "errors outside of tests")
      diagnosis = Diagnosis.new(name: summary.name, id: summary.id, file_runs: summary, isolated_runs: nil,
                                culprits: nil)
      out = StringIO.new
      TextReport.new(out).print([diagnosis])

      assert_equal "errors outside of tests: none in 1 runs, but leaks\n  leaks: $x was set (1 of 1 runs)\n",
                   out.string
    end

    def test_a_random_failure_still_tells_how_to_reproduce_it
      culprits = Culprits.new(ids: [], command: "ruby -Itest t.rb --seed 5")
      summary = Summary.new([Run.new(seed: 5, passed: false, error: "boom")], id: "T#test_a", name: "T#test_a")
      alone = Summary.new([Run.new(seed: 6, passed: true, error: nil)])
      diagnosis = Diagnosis.new(name: "T#test_a", id: "T#test_a", file_runs: summary, isolated_runs: alone,
                                culprits: culprits)
      out = StringIO.new
      TextReport.new(out).print([diagnosis])

      assert_includes out.string, "reproduce: ruby -Itest t.rb --seed 5"
    end

    # Two tests of a group break the victim: the group's hook is not to blame
    module TwoPolluters
      module_function

      def group(id) = id[/\A\w+/]

      def run_in_order(_path, ids, seed:) # rubocop:disable Lint/UnusedMethodArgument
        broken = ids[0...-1].intersect?(%w[A#one A#two])
        ids.map { |id| { "id" => id, "passed" => !(id == "V#victim" && broken) } }
      end
    end

    # Gives bisect this order of the whole file instead of running it
    module FakeOrder
      class << self
        attr_accessor :ids
      end

      def order(...) = FakeOrder.ids ? [FakeOrder.ids, false] : super
    end
    Execution.singleton_class.prepend(FakeOrder)

    def test_a_second_polluter_of_a_group_does_not_blame_the_group
      FakeOrder.ids = %w[A#one A#two A#three V#victim]
      bisect = Bisect.new("t.rb", seed: 1, adapter: TwoPolluters)

      refute_empty bisect.call("V#victim")
      assert_empty bisect.group_wide
    ensure
      FakeOrder.ids = nil
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
