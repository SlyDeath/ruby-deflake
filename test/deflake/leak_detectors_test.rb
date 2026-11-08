# frozen_string_literal: true

require "test_helper"
require "deflake/leaks"

module Deflake
  class LeakDetectorsTest < Minitest::Test
    def test_env_tells_set_changed_and_removed_variables
      leaks = Leaks::Env.new.diff({ "A" => "1", "B" => "1" }, { "A" => "2", "C" => "1" })

      assert_equal ['ENV["A"] was changed', 'ENV["B"] was removed', 'ENV["C"] was set'], leaks
    end

    def test_clock_ignores_small_drift_and_reports_travel_back_in_time
      clock = Leaks::Clock.new

      assert_empty clock.diff([0.0, false], [0.5, false])
      assert_equal ["Time.now is 2 hours behind the real clock (travel_to without travel_back?)"],
                   clock.diff([0.0, false], [-7200.0, false])
    end

    def test_clock_reports_a_frozen_clock_but_not_its_drift
      clock = Leaks::Clock.new

      assert_equal ["Time.now is frozen (freeze_time or travel_to without travel_back?)"],
                   clock.diff([0.0, false], [0.0, true])
      assert_empty clock.diff([-1.0, true], [-3.0, true])
    end

    # The offset of a frozen clock grows every second, which would split one leak into many
    def test_clock_reports_a_frozen_clock_the_same_way_however_long_it_stood
      clock = Leaks::Clock.new

      assert_equal clock.diff([0.0, false], [0.0, true]), clock.diff([0.0, false], [-2.5, true])
    end

    def test_clock_sees_time_standing_still
      refute Leaks::Clock.new.snapshot.last
    end

    def test_rows_reports_created_and_deleted_rows
      before = rows({ "users" => 1, "posts" => 3 })

      leaks = Leaks::Rows.new.diff(before, rows({ "users" => 3, "posts" => 2, "tags" => 0 }))

      assert_equal ["posts: 1 row deleted for good", "users: 2 rows left behind"], leaks
    end

    def test_rows_compares_with_the_counts_after_fixtures_were_loaded
      Leaks::Rows.fixtures_loaded(main({ "users" => 2 }))

      leaks = Leaks::Rows.new.diff(rows({ "users" => 0 }, loads: Leaks::Rows.loads - 1), rows({ "users" => 3 }))

      assert_equal ["users: 1 row left behind"], leaks
    end

    # A test without a transaction loads the fixtures and deletes them again in teardown
    def test_rows_ignore_fixtures_deleted_by_the_test_that_loaded_them
      Leaks::Rows.fixtures_loaded(main({ "users" => 2 }))

      leaks = Leaks::Rows.new.diff(rows({ "users" => 0 }, loads: Leaks::Rows.loads - 1), rows({ "users" => 0 }))

      assert_empty leaks
    end

    # Its rows were there before the test, which only connected to it
    def test_rows_skip_a_database_connected_during_the_test
      before = Leaks::Rows::State.new(main({ "users" => 1 }), Leaks::Rows.loads.to_i)
      after = Leaks::Rows::State.new(main({ "users" => 1 }).merge("AnimalsRecord" => { "dogs" => 5 }),
                                     Leaks::Rows.loads.to_i)

      assert_empty Leaks::Rows.new.diff(before, after)
    end

    def test_rows_name_tables_of_other_databases_by_their_model
      before = Leaks::Rows::State.new({ "AnimalsRecord" => { "dogs" => 0 } }, Leaks::Rows.loads.to_i)
      after = Leaks::Rows::State.new({ "AnimalsRecord" => { "dogs" => 1 } }, Leaks::Rows.loads.to_i)

      assert_equal ["AnimalsRecord.dogs: 1 row left behind"], Leaks::Rows.new.diff(before, after)
    end

    def test_cache_lists_only_a_few_new_keys
      leaks = Leaks::Cache.new.diff(["old"], %w[old a b c d])

      assert_equal ['Rails.cache has 4 new keys: "a", "b", "c", ...'], leaks
    end

    def test_current_ignores_attributes_reset_to_nil
      before = Leaks::Current::State.new({ "Current" => {} }, {})
      after = Leaks::Current::State.new({ "Current" => { user: nil, account: 1 } }, {})
      leaks = Leaks::Current.new.diff(before, after)

      assert_equal ["Current.account is still set"], leaks
    end

    def test_globals_treat_nil_as_unset
      globals = Leaks::Globals.new

      assert_equal ["$a was changed", "$b was set"], globals.diff({ "$a": 1 }, { "$b": 2 })
    end

    Settings = Struct.new(:debug)

    # Object#hash of a plain object stays the same whatever happens inside it
    def test_globals_see_a_change_inside_an_object
      settings = Settings.new(false)
      holder = Object.new.tap { |object| object.instance_variable_set(:@settings, settings) }
      globals = Leaks::Globals.new
      before = globals.send(:fingerprint, holder)
      settings.debug = true

      refute_equal before, globals.send(:fingerprint, holder)
    end

    def test_globals_ignore_english_names_of_special_variables
      require "English"
      `true`

      refute_includes Leaks::Globals.new.snapshot.keys, :$CHILD_STATUS
    end

    def test_jobs_tell_a_new_job_from_an_old_one
      assert_equal ["1 enqueued job left in the ActiveJob queue"], Leaks::Jobs.new.diff([1], [2])
      assert_empty Leaks::Jobs.new.diff([1, 2], [2])
    end

    private

    def rows(counts, loads: Leaks::Rows.loads.to_i)
      Leaks::Rows::State.new(main(counts), loads)
    end

    def main(counts)
      { Leaks::Rows::MAIN => counts }
    end
  end
end
