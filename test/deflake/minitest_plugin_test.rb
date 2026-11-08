# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "English"

module Deflake
  class MinitestPluginTest < Minitest::Test
    SAMPLE = File.expand_path("../fixtures/sample.rb", __dir__)

    def test_writes_every_test_result_to_file
      results = run_sample(seed: 42).reject { |row| row.key?("started") }.sort_by { |result| result["name"] }

      assert_equal [
        line("SampleTest#test_fails", passed: false, error: "Expected: 2\n  Actual: 1"),
        line("SampleTest#test_passes", passed: true),
        line("SampleTest#test_raises", passed: false, error: "RuntimeError: boom"),
        { "id" => "SampleTest#test_skipped", "name" => "SampleTest#test_skipped", "skipped" => true, "seed" => 42,
          "leaks" => [] }
      ], results
    end

    def test_marks_every_test_as_started_before_it_runs
      rows = run_sample(seed: 42)

      rows.each_slice(2) { |started, finished| assert_equal started["started"], finished["id"] }
    end

    def test_runs_only_the_given_tests_in_the_given_order
      Dir.mktmpdir do |dir|
        order = File.join(dir, "order")
        File.write(order, ResultFile.pack_ids(%w[SampleTest#test_passes SampleTest#test_fails]))

        rows = run_sample(seed: 1, env: { ResultFile::ORDER_KEY => order })

        assert_equal(%w[SampleTest#test_passes SampleTest#test_fails], rows.filter_map { |row| row["id"] })
      end
    end

    def test_runs_only_the_tests_passed_in_the_environment
      rows, status = run_sample(seed: 1, env: Adapters::Minitest.env("SampleTest#test_passes"), status: true)

      assert_equal(%w[SampleTest#test_passes], rows.filter_map { |row| row["id"] })
      assert_predicate status, :success?
    end

    def test_lists_every_test_with_the_line_it_is_defined_at
      rows = run_sample(seed: 1, env: { ResultFile::LIST_KEY => SAMPLE })

      assert_equal [["SampleTest#test_fails", 11], ["SampleTest#test_passes", 7]],
                   rows.map { |row| [row["listed"], row["line"]] }.sort.first(2)
      refute(rows.any? { |row| row.key?("started") || row.key?("passed") })
    end

    private

    # One expected line of the results file
    def line(name, passed:, error: nil, seed: 42)
      { "id" => name, "name" => name, "passed" => passed, "seed" => seed, "error" => error, "leaks" => [] }
    end

    def run_sample(seed:, env: {}, status: false)
      Dir.mktmpdir do |dir|
        output = File.join(dir, "results.jsonl")
        system(env.merge(ResultFile::ENV_KEY => output), *Adapters::Minitest.command(SAMPLE, seed: seed),
               out: File::NULL, err: File::NULL)
        status ? [ResultFile.read(output), $CHILD_STATUS] : ResultFile.read(output)
      end
    end
  end
end
