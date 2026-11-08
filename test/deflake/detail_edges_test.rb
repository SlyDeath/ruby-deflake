# frozen_string_literal: true

require "test_helper"
require "stringio"
require "deflake/leaks"

module Deflake
  # Small pieces where a wrong answer is easy: leak detectors, reports, the command line
  class DetailEdgesTest < Minitest::Test
    # Connects and creates its lock on first use, as many clients do
    class LazyClient
      def initialize
        @url = "redis://localhost"
      end

      def get
        @lock ||= Mutex.new # rubocop:disable Naming/MemoizedInstanceVariableName
      end
    end

    def test_globals_ignore_what_an_object_sets_up_on_first_use
      client = LazyClient.new
      globals = Leaks::Globals.new
      before = globals.send(:fingerprint, client)
      client.get

      assert globals.send(:same?, before, globals.send(:fingerprint, client))
    end

    def test_globals_ignore_the_order_of_a_hash_and_ignore_the_last_read_line
      features = { a: 1, b: 2 }
      globals = Leaks::Globals.new
      before = globals.send(:fingerprint, features)
      features[:a] = features.delete(:a)

      assert globals.send(:same?, before, globals.send(:fingerprint, features))
      assert_includes Leaks::Globals::IGNORED, :$_
    end

    def test_globals_see_a_value_without_kernel_methods
      globals = Leaks::Globals.new
      value = BasicObject.new

      before = globals.send(:safely, value)

      assert globals.send(:same?, before, globals.send(:safely, value))
      value.instance_eval { @changed = true }

      refute globals.send(:same?, before, globals.send(:safely, value))
    end

    def test_clock_tells_where_the_clock_ends_up
      clock = Leaks::Clock.new

      assert_empty clock.diff([86_400.0, false], [0.2, false]), "brought back a clock another test moved"
      assert_equal ["Time.now is 1 day ahead of the real clock (travel_to without travel_back?)"],
                   clock.diff([0.0, false], [86_399.9999, false])
      assert_equal clock.diff([0.0, false], [86_399.9999, false]), clock.diff([0.0, false], [86_400.0001, false])
    end

    # As Timecop's mock_process_clock does, only while asked to
    module FrozenProcessClock
      def clock_gettime(*args)
        Thread.current[:deflake_frozen_clock] ? 0.0 : super
      end
    end
    Process.singleton_class.prepend(FrozenProcessClock)

    def test_clock_reads_the_real_clock_even_when_a_test_mocks_it
      Thread.current[:deflake_frozen_clock] = true

      assert_operator Leaks::Clock.new.send(:real), :>, 1_000_000
    ensure
      Thread.current[:deflake_frozen_clock] = nil
    end

    def test_cache_keys_with_times_in_them_make_one_leak
      cache = Leaks::Cache.new

      assert_equal cache.diff([], ["session-1699999999"]), cache.diff([], ["session-1700000123"])
    end

    def test_current_tells_a_default_changed_in_place
      before = Leaks::Current::State.new({}, { "Current" => { "flags" => Marshal.dump([]).hash } })
      after = Leaks::Current::State.new({}, { "Current" => { "flags" => Marshal.dump([:beta]).hash } })

      assert_equal ["Current.flags's default was changed in place"], Leaks::Current.new.diff(before, after)
    end

    def test_rows_count_from_the_last_load_that_wrote_to_each_table
      Leaks::Rows.instance_variable_set(:@loads, 0)
      Leaks::Rows.fixtures_loaded({ "ActiveRecord::Base" => { "posts" => 1, "comments" => 0 } }, %w[posts])
      Leaks::Rows.fixtures_loaded({ "ActiveRecord::Base" => { "posts" => 2, "comments" => 1 } }, %w[comments])
      before = Leaks::Rows::State.new({ "ActiveRecord::Base" => { "posts" => 0, "comments" => 0 } }, 0)
      after = Leaks::Rows::State.new({ "ActiveRecord::Base" => { "posts" => 2, "comments" => 1 } }, 2)

      assert_equal ["posts: 1 row left behind"], Leaks::Rows.new.diff(before, after)
    ensure
      Leaks::Rows.instance_variable_set(:@loads, nil)
      Leaks::Rows.fixture_loads.clear
    end

    def test_summary_keeps_numbers_that_are_not_addresses
      runs = [Run.new(seed: 1, passed: false, error: "expected 0x1234abcd, got 0x9876fedc"),
              Run.new(seed: 2, passed: false, error: "expected 0x1234abcd, got 0x11111111"),
              Run.new(seed: 3, passed: false, error: "#<User:0x000055d5a1b2c3d4> is invalid"),
              Run.new(seed: 4, passed: false, error: "#<User:0x000055d5ffffffff> is invalid")]

      assert_equal 3, Summary.new(runs).errors.size
    end

    def test_result_file_converts_text_in_another_encoding
      assert_equal "café", ResultFile.clean("café".encode(Encoding::ISO_8859_1))
      assert_equal "caf�", ResultFile.clean("caf\xE9".b)
    end

    def test_result_file_writes_json_without_the_json_library
      line = ResultFile.generate({ "a" => "x\"\n\u0001é", "b" => [1, nil, true], "c" => 1.5 })

      assert_equal({ "a" => "x\"\n\u0001é", "b" => [1, nil, true], "c" => 1.5 }, JSON.parse(line))
    end

    def test_runner_gives_every_run_its_own_seed
      seeds = Runner.new("x.rb", runs: 500, adapter: Adapters::Minitest).send(:seeds)

      assert_equal 500, seeds.uniq.size
    end
  end
end
