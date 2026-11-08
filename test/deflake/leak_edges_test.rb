# frozen_string_literal: true

require "test_helper"
require "stringio"
require "deflake/leaks"

module Deflake
  # Leak detectors on state that is unusual but real
  class LeakEdgesTest < Minitest::Test
    FIXTURES = File.expand_path("../fixtures", __dir__)

    # Timecop can freeze the system clock as well as Time.now
    def test_clock_does_not_wait_forever_for_a_frozen_system_clock
      frozen = Class.new(Leaks::Clock) do
        def now = Time.at(0)
        def real = 0.0
      end

      assert_equal [0.0, true], frozen.new.snapshot
    end

    def test_rows_count_fixture_tables_from_the_load_whatever_was_there_before
      Leaks::Rows.fixtures_loaded({ "ActiveRecord::Base" => { "users" => 2, "posts" => 1 } }, ["users"])
      before = state({ "users" => 3, "posts" => 1 }, Leaks::Rows.loads - 1)

      assert_equal ["users: 1 row left behind"], Leaks::Rows.new.diff(before, state({ "users" => 3, "posts" => 1 }))
      assert_empty Leaks::Rows.new.diff(before, state({ "users" => 0, "posts" => 1 }))
      assert_equal ["posts: 1 row deleted for good"],
                   Leaks::Rows.new.diff(before, state({ "users" => 2, "posts" => 0 }))
    end

    def test_rows_report_leaks_around_fixtures_loaded_by_every_test
      assert_equal({ "ATransactionalTest#test_loads_fixtures" => [],
                     "BLeakyTest#test_a_leaks" => ["users: 1 row left behind"],
                     "BLeakyTest#test_b_leaks" => ["users: 1 row left behind"],
                     "CCleanTest#test_reads_fixtures" => [] }, leaks_of("rails_fixture_leaks.rb", runs: 3))
    end

    # The join table of has_and_belongs_to_many and a second load in setup are fixtures too
    def test_rows_count_every_table_a_fixture_load_wrote_to
      assert_equal({ "HabtmTest#test_reads_tags" => [], "SecondLoadTest#test_reads_comments" => [] },
                   leaks_of("rails_fixture_tables.rb", runs: 2))
    end

    def test_rows_follow_the_writing_role_of_the_application
      assert_equal({ "WritingRoleTest#test_leaves_a_row" => ["users: 1 row left behind"] },
                   leaks_of("rails_writing_role.rb"))
    end

    def test_rows_watch_every_shard
      assert_equal({ "ShardTest#test_leaves_a_row_in_another_shard" => ["ShardRecord[one].events: 1 row left behind"] },
                   leaks_of("rails_shards.rb"))
    end

    Registry = Struct.new(:lock, :items)

    def test_globals_see_a_change_inside_an_object_marshal_cannot_dump
      globals = Leaks::Globals.new
      registry = Registry.new(Mutex.new, [])
      before = globals.send(:fingerprint, registry)
      registry.items << :added

      refute_equal before, globals.send(:fingerprint, registry)
    end

    # What a client keeps inside, such as a connection opened on first use, is its own business
    def test_globals_leave_objects_marshal_cannot_dump_alone
      assert_equal({ "LazyGlobalTest#test_one" => [], "LazyGlobalTest#test_two" => [] }, leaks_of("lazy_global.rb"))
    end

    def test_globals_see_what_a_queue_or_a_string_io_holds
      globals = Leaks::Globals.new
      queue = Queue.new
      io = StringIO.new
      before = [queue, io].map { |value| globals.send(:fingerprint, value) }
      queue << 1
      io.write("x")

      after = [queue, io].map { |value| globals.send(:fingerprint, value) }

      refute_equal before[0], after[0]
      refute_equal before[1], after[1]
    end

    def test_globals_survive_a_structure_too_deep_for_marshal
      deep = (1..200_000).reduce(nil) { |tail, _| [tail] }

      globals = Leaks::Globals.new
      print = globals.send(:fingerprint, deep)

      assert globals.send(:same?, print, globals.send(:fingerprint, deep))
    end

    private

    def state(counts, loads = Leaks::Rows.loads)
      Leaks::Rows::State.new({ "ActiveRecord::Base" => counts }, loads)
    end

    def leaks_of(fixture, runs: 1)
      summaries = Runner.new(File.join(FIXTURES, fixture), runs: runs).call.values
      summaries.sort_by(&:name).to_h { |summary| [summary.name, summary.leaks.keys] }
    end
  end
end
