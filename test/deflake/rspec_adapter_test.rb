# frozen_string_literal: true

require "test_helper"

module Deflake
  class RSpecAdapterTest < Minitest::Test
    SAMPLE = File.expand_path("../fixtures/sample_spec.rb", __dir__)

    def test_picks_rspec_for_spec_files
      assert_equal Adapters::RSpec, Adapters.for("spec/models/user_spec.rb")
      assert_equal Adapters::Minitest, Adapters.for("test/models/user_test.rb")
    end

    def test_sends_minitest_spec_files_to_minitest
      assert_equal Adapters::Minitest, Adapters.for(fixture("minitest_style_spec.rb"))
      assert_equal Adapters::RSpec, Adapters.for(SAMPLE)
    end

    # Minitest::Spec projects have a spec_helper too
    def test_sends_minitest_spec_files_with_a_spec_helper_to_minitest
      assert_equal Adapters::Minitest, Adapters.for(fixture("helper_spec.rb"))
    end

    # Under LANG=C Ruby reads files as US-ASCII by default
    def test_reads_spec_files_as_utf8_whatever_the_locale
      lib = File.expand_path("../../lib", __dir__)
      script = "print Deflake::Adapters.for(ARGV.first)"

      command = [RbConfig.ruby, "-EUS-ASCII", "-I", lib, "-rdeflake", "-e", script, fixture("helper_spec.rb")]

      output = IO.popen(command, &:read)

      assert_equal "Deflake::Adapters::Minitest", output
    end

    def test_joins_example_ids_of_one_file
      assert_equal ["./spec/a_spec.rb[1:1,1:3]", "./spec/b_spec.rb[2:1]"],
                   Adapters::RSpec.compact(["./spec/a_spec.rb[1:1]", "./spec/a_spec.rb[1:3]", "./spec/b_spec.rb[2:1]"])
    end

    # A flaky pending example would otherwise show only its runs that passed, as failures
    def test_counts_a_pending_example_that_ran_and_leaves_out_a_skipped_one
      summaries = Runner.new(fixture("pending_spec.rb"), runs: 1).call

      assert_equal({ "Pending fails as expected" => [0, 1] },
                   summaries.values.to_h { |summary| [summary.name, [summary.failures, summary.total]] })
    end

    def test_runs_a_spec_with_rspec_autorun_only_once
      summaries = Runner.new(fixture("autorun_spec.rb"), runs: 1).call

      assert_equal [1], summaries.values.map(&:total)
    end

    # A pending example runs and passes by failing, so its runs count
    def test_runs_spec_file_several_times_and_counts_pending_examples
      summaries = Runner.new(SAMPLE, runs: 2).call

      failures_and_totals = summaries.values.to_h { |summary| [summary.name, [summary.failures, summary.total]] }

      assert_equal({ "Sample fails" => [2, 2], "Sample is pending" => [0, 2], "Sample passes" => [0, 2] },
                   failures_and_totals)
    end

    def test_records_error_and_example_id
      summary = by_name(Runner.new(SAMPLE, runs: 1).call).fetch("Sample fails")

      assert_match(/expected: 2\n\s+got: 1/, summary.errors.keys.first)
      assert_match(/sample_spec\.rb\[1:2\]\z/, summary.id)
    end

    def test_runs_only_one_example
      id = by_name(Runner.new(SAMPLE, runs: 1).call).fetch("Sample passes").id

      summaries = Runner.new(SAMPLE, runs: 1, only: id).call

      assert_equal ["Sample passes"], summaries.values.map(&:name)
    end

    private

    def fixture(name)
      File.expand_path("../fixtures/#{name}", __dir__)
    end

    def by_name(summaries)
      summaries.values.to_h { |summary| [summary.name, summary] }
    end
  end
end
