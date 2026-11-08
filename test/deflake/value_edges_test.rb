# frozen_string_literal: true

require "test_helper"
require "deflake/leaks"

module Deflake
  # Values that are easy to compare wrongly: procs in containers, big hashes, addresses of objects
  class ValueEdgesTest < Minitest::Test
    def test_globals_see_a_proc_added_to_an_array_or_a_hash
      globals = Leaks::Globals.new
      callbacks = []
      handlers = {}
      before = [callbacks, handlers].map { |value| globals.send(:fingerprint, value) }
      callbacks << -> {}
      handlers[:changed] = proc {}

      refute globals.send(:same?, before[0], globals.send(:fingerprint, callbacks))
      refute globals.send(:same?, before[1], globals.send(:fingerprint, handlers))
    end

    # Opens its lock on first use
    class LazyClient
      def get
        @lock ||= Mutex.new # rubocop:disable Naming/MemoizedInstanceVariableName
      end
    end

    def test_globals_ignore_what_an_object_in_a_container_sets_up_on_first_use
      globals = Leaks::Globals.new
      client = LazyClient.new
      clients = { main: client }
      before = globals.send(:fingerprint, clients)
      client.get

      assert globals.send(:same?, before, globals.send(:fingerprint, clients))
    end

    def test_globals_see_a_new_default_of_a_hash
      globals = Leaks::Globals.new
      settings = {}
      before = globals.send(:fingerprint, settings)
      settings.default = :on

      refute globals.send(:same?, before, globals.send(:fingerprint, settings))
    end

    def test_globals_compare_a_big_hash_of_procs_quickly
      globals = Leaks::Globals.new
      handlers = (1..20_000).to_h { |key| [key, proc {}] }
      before = globals.send(:fingerprint, handlers)
      handlers[1] = handlers.delete(1)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      assert globals.send(:same?, before, globals.send(:fingerprint, handlers))
      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
    end

    def test_summary_treats_addresses_of_namespaced_classes_as_one_error
      runs = [Run.new(seed: 1, passed: false, error: "#<Shop::Order:0x000055d5a1b2c3d4> is invalid"),
              Run.new(seed: 2, passed: false, error: "#<Shop::Order:0x000055d5ffffffff> is invalid")]

      assert_equal ["#<Shop::Order:0x...> is invalid"], Summary.new(runs).errors.keys
    end

    def test_summary_groups_crashes_whose_output_changes_with_the_seed
      runs = [Run.new(seed: 1, passed: false, error: "killed, output: a", group: "killed"),
              Run.new(seed: 2, passed: false, error: "killed, output: b", group: "killed")]

      assert_equal({ "killed, output: a" => [1, 2] }, Summary.new(runs).errors)
    end

    def test_fixtures_loaded_in_a_transaction_open_before_the_test_are_a_baseline
      rows = Leaks::Rows
      rows.depth = 1
      rows.define_singleton_method(:open_transactions) { 1 }

      refute_predicate rows, :in_new_transaction?
      rows.define_singleton_method(:open_transactions) { 2 }

      assert_predicate rows, :in_new_transaction?
    ensure
      rows.singleton_class.send(:remove_method, :open_transactions)
      rows.depth = nil
    end

    def test_leaks_of_a_group_tell_names_with_numbers_apart_and_add_up_cache_keys
      assert_equal ["$retry2 was set"], Leaks.own(["$retry2 was set"], ["$retry1 was set"])
      assert_empty Leaks.own(['Rails.cache has 2 new keys: "a", "b"'],
                             ['Rails.cache has 1 new key: "a"', 'Rails.cache has 1 new key: "b"'])
    end
  end
end
