# frozen_string_literal: true

require "test_helper"

module Deflake
  class RunnerTest < Minitest::Test
    SAMPLE = File.expand_path("../fixtures/sample.rb", __dir__)

    def test_runs_file_several_times_and_summarizes_every_test
      summaries = Runner.new(SAMPLE, runs: 3).call

      failures_and_totals = summaries.transform_values { |summary| [summary.failures, summary.total] }

      expected = { "SampleTest#test_fails" => [3, 3], "SampleTest#test_passes" => [0, 3],
                   "SampleTest#test_raises" => [3, 3] }

      assert_equal expected, failures_and_totals
    end

    def test_finds_test_helper_like_a_real_project
      project = File.expand_path("../fixtures/project", __dir__)

      summaries = Dir.chdir(project) { Runner.new("test/uses_helper.rb", runs: 1).call }

      assert_equal ["UsesHelperTest#test_passes"], summaries.keys
    end

    def test_gives_every_parallel_job_its_own_test_env_number
      worker = File.expand_path("../fixtures/worker.rb", __dir__)

      summary = Runner.new(worker, runs: 6, jobs: 2).call.fetch("WorkerTest#test_reports_worker")

      assert_equal 6, summary.total
      assert_equal ['worker ""', 'worker "2"'], summary.errors.keys.sort
    end

    # test_dies kills its process in about half of the runs, so 30 runs miss it once in a billion
    def test_counts_a_test_that_killed_its_process_as_failed
      summary = Runner.new(fixture("crash.rb"), runs: 30).call.fetch("CrashTest#test_dies")

      assert_equal 30, summary.total
      assert_operator summary.failures, :positive?
      # Followed by the end of the output, which warnings of the Ruby version may fill
      assert_match(/\Athe test process exited with status 1 during this test/, summary.errors.keys.join("|"))
    end

    def test_records_an_error_message_that_is_not_utf8
      summary = Runner.new(fixture("binary_error.rb"), runs: 2).call.fetch("BinaryErrorTest#test_raises_bytes")

      assert_equal 2, summary.failures
      assert_equal ["RuntimeError: bad byte \uFFFD"], summary.errors.keys
    end

    def test_runs_only_the_test_with_slashes_in_its_name
      summaries = Runner.new(fixture("slash.rb"), runs: 1, only: "SlashTest#test_GET_/users/1_works").call

      assert_equal ["SlashTest#test_GET_/users/1_works"], summaries.keys
    end

    def test_rejects_zero_runs
      assert_raises(ArgumentError) { Runner.new(SAMPLE, runs: 0) }
    end

    def test_runs_only_one_test
      summaries = Runner.new(SAMPLE, runs: 1, only: "SampleTest#test_passes").call

      assert_equal ["SampleTest#test_passes"], summaries.keys
    end

    def test_leaves_out_tests_in_anonymous_classes
      summaries = Runner.new(fixture("anonymous.rb"), runs: 1).call

      assert_equal({ "NamedTest#test_named" => 0 }, summaries.transform_values(&:failures))
    end

    # Minitest 5 loads gem plugins only while no plugin is registered
    def test_keeps_the_minitest_plugins_of_other_gems
      path = fixture("plugin_probe.rb")
      env = { "RUBYLIB" => [fixture("plugins"), ENV.fetch("RUBYLIB", nil)].compact.join(File::PATH_SEPARATOR) }
      plain = system(env, RbConfig.ruby, path, out: File::NULL, err: File::NULL)

      rows = Execution.call(Adapters::Minitest, path, seed: 1, env: env)

      assert_equal([plain], rows.map { |row| row["passed"] })
    end

    private

    def fixture(name)
      File.expand_path("../fixtures/#{name}", __dir__)
    end
  end
end
