# frozen_string_literal: true

require "test_helper"
require "deflake/leaks"

module Deflake
  class LeaksTest < Minitest::Test
    FIXTURES = File.expand_path("../fixtures", __dir__)

    def test_finds_env_time_and_global_leaks_in_minitest
      leaks = leaks_of("leaky.rb")

      assert_equal({ "LeakyTest#test_cleans_up" => [],
                     "LeakyTest#test_sets_env" => ['ENV["DEFLAKE_FIXTURE_LEAK"] was set'],
                     "LeakyTest#test_sets_global" => ["$deflake_fixture_leak was set"],
                     "LeakyTest#test_travels_in_time" => [
                       "Time.now is 3 days ahead of the real clock (travel_to without travel_back?)"
                     ] }, leaks)
    end

    def test_finds_leaks_in_rspec
      leaks = leaks_of("leaky_spec.rb")

      assert_equal({ "Leaky cleans up" => [],
                     "Leaky sets a global" => ["$deflake_fixture_leak was set"],
                     "Leaky sets env" => ['ENV["DEFLAKE_FIXTURE_LEAK"] was set'] }, leaks)
    end

    def test_finds_rails_leaks
      leaks = leaks_of("rails_leaky.rb")

      assert_equal({ "RailsLeakyTest#test_enqueues_a_job" => ["1 enqueued job left in the ActiveJob queue"],
                     "RailsLeakyTest#test_fills_cache" => ['Rails.cache has 1 new key: "users/1"'],
                     "RailsLeakyTest#test_leaves_a_dog" => ["AnimalsRecord.dogs: 1 row left behind"],
                     "RailsLeakyTest#test_leaves_a_row" => ["users: 1 row left behind"],
                     "RailsLeakyTest#test_rolls_back_its_row" => [],
                     "RailsLeakyTest#test_sets_current" => ["Current.user is still set"] }, leaks)
    end

    def test_reports_nothing_for_tests_that_leave_no_state_behind
      assert_equal({ "QuietTest#test_reads_a_file" => [], "QuietTest#test_reads_an_unset_global" => [],
                     "QuietTest#test_shells_out" => [] }, leaks_of("quiet.rb"))
    end

    def test_reports_a_frozen_clock_and_not_the_slow_test_after_it
      assert_equal({ "FrozenTest#test_freezes_time" => [
                       "Time.now is frozen (freeze_time or travel_to without travel_back?)"
                     ],
                     "FrozenTest#test_slow" => [] }, leaks_of("frozen.rb"))
    end

    # The executor clears Current, CurrentAttributes::TestHelper resets proc
    # defaults, and the first test loads fixtures: none of that is a leak
    def test_reports_nothing_for_what_rails_cleans_up_itself
      leaks = leaks_of("rails_quiet.rb", runs: 2)

      assert_equal 4, leaks.size
      assert_equal [[]], leaks.values.uniq
    end

    def test_leaves_activejob_test_adapter_alone
      summary = Runner.new(File.join(FIXTURES, "rails_jobs.rb"), runs: 1).call.fetch("EnqueueTest#test_enqueues")

      assert_equal 0, summary.failures
    end

    def test_a_broken_detector_does_not_break_the_others
      broken = Object.new
      def broken.snapshot = raise(NotImplementedError)

      Leaks.detectors << broken
      snapshot = Leaks.snapshot
      ENV["DEFLAKE_TEST_LEAK"] = "1"

      assert_equal ['ENV["DEFLAKE_TEST_LEAK"] was set'], Leaks.since(snapshot)
    ensure
      Leaks.detectors.delete(broken)
      ENV.delete("DEFLAKE_TEST_LEAK")
    end

    def test_a_broken_row_count_does_not_break_loading_fixtures
      summary = Runner.new(File.join(FIXTURES, "rails_fixture_count_error.rb"), runs: 1).call
                      .fetch("FixturesTest#test_reads_fixtures")

      assert_equal 0, summary.failures
    end

    # Its rows were there before the test, which only connected to it
    def test_reports_nothing_for_a_database_the_test_connected_to_first
      assert_equal({ "ReadsDogsTest#test_counts_dogs" => [] }, leaks_of("rails_second_db.rb"))
    end

    def test_reports_nothing_for_fixtures_a_test_without_a_transaction_deletes_again
      assert_equal({ "NonTransactionalTest#test_reads_fixtures" => [],
                     "NonTransactionalTest#test_reads_fixtures_again" => [] }, leaks_of("rails_non_transactional.rb"))
    end

    # Checking for leaks must not compute the default before the test travels in time
    def test_leaves_current_attribute_defaults_to_the_test
      summary = Runner.new(File.join(FIXTURES, "current_default.rb"), runs: 1).call
                      .fetch("StartedAtTest#test_started_at_follows_travel")

      assert_equal 0, summary.failures
    end

    def test_reports_leaks_of_a_test_that_skipped_itself
      summary = Runner.new(File.join(FIXTURES, "skip_leak.rb"), runs: 2).call
                      .fetch("SkipLeakTest#test_sets_env_then_skips")

      assert_equal [0, 2], [summary.total, summary.skipped]
      assert_includes summary.leaks.keys, 'ENV["DEFLAKE_FIXTURE_SKIP_LEAK"] was set'
    end

    def test_blames_only_the_parallel_test_that_leaked
      assert_equal({ "ParallelTest#test_leaks_late" => ["$deflake_fixture_parallel was set"],
                     "ParallelTest#test_slow" => [] }, leaks_of("parallel.rb"))
    end

    private

    def leaks_of(fixture, runs: 1)
      summaries = Runner.new(File.join(FIXTURES, fixture), runs: runs).call.values
      summaries.sort_by(&:name).to_h { |summary| [summary.name, summary.leaks.keys] }
    end
  end
end
