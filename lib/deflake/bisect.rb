# frozen_string_literal: true

module Deflake
  # Finds the smallest set of tests that make a test fail when they run before it.
  # Works with any adapter that can run a list of tests in a given order (run_in_order), and
  # tell the group of a test (group) if it can.
  # A failure counts only when it repeats: a test that fails at random would otherwise
  # get culprits that have nothing to do with it
  class Bisect
    # How many runs in a row a failure must happen in to count
    CONFIRM = 2
    # How many other tests of a group must stand in for a culprit
    STAND_INS = 2

    def initialize(path, seed:, adapter:)
      @path = path
      @seed = seed
      @adapter = adapter
      @alone = false
      @group_wide = []
      @hidden = false
    end

    # Whether the failure did not happen again, and tests that cannot run by name, such as those
    # in a class without a name, ran in the whole file: one of them may be the culprit
    def hidden? = @hidden

    # Whether the victim failed with this seed with no test before it
    def alone? = @alone

    # Culprits that other tests of their group stand in for, so their group's hook is to blame
    attr_reader :group_wide

    # Returns culprit ids, or an empty array if the failure does not reproduce or happens alone
    def call(victim)
      @order, unnamed = Execution.retrying { Execution.order(@adapter, @path, seed: @seed) }
      before = @order.take_while { |id| id != victim }
      return hidden(unnamed) unless fails?(before, victim, CONFIRM)
      return alone if fails?([], victim, CONFIRM)

      confirmed(minimize(before) { |tests| fails?(tests, victim) }, victim)
    rescue Execution::NoResults
      # The process broke before its first test every time, so the failure did not reproduce
      []
    end

    private

    def alone
      @alone = true
      []
    end

    def hidden(unnamed)
      @hidden = unnamed
      []
    end

    # Smaller steps ran once each, so the end result must break the victim again
    def confirmed(culprits, victim)
      return [] unless culprits.any? && fails?(culprits, victim, CONFIRM)

      @group_wide = group_wide_of(culprits, victim)
      culprits
    end

    # Only this victim counts: other tests may fail too, a skipped victim did not fail, and neither
    # did one stopped by the timeout, which a shorter list of tests would not reach. A run that
    # broke before its first test, as a flaky boot does now and then, is tried again
    def fails?(tests, victim, times = 1)
      times.times.all? do
        rows = Execution.retrying { @adapter.run_in_order(@path, tests + [victim], seed: @seed) }
        rows.any? { |row| row["id"] == victim && row["passed"] == false && !row["timed_out"] }
      rescue Execution::NoResults
        false
      end
    end

    # Drops ever smaller chunks of candidates while the failure still happens
    def minimize(candidates)
      size = (candidates.size / 2.0).ceil
      while size.positive?
        candidates.each_slice(size).to_a.each do |chunk|
          rest = candidates - chunk
          candidates = rest if yield(rest)
        end
        size /= 2
      end
      candidates
    end

    # A culprit that other tests of its group replace with the same failure is not to blame
    # itself: the group's hooks are, such as before(:context) or minitest-hooks' before_all.
    # Two of them must, as one may break the victim on its own
    def group_wide_of(culprits, victim)
      culprits.select do |culprit|
        stand_ins = stand_ins(culprit, culprits + [victim])
        stand_ins.any? && stand_ins.all? do |stand_in|
          fails?(in_order(culprits - [culprit] + [stand_in]), victim, CONFIRM)
        end
      end
    end

    # Other tests of the culprit's group, none of these. An adapter that knows no groups has none
    def stand_ins(culprit, taken)
      group = @adapter.respond_to?(:group) && @adapter.group(culprit) or return []
      @order.select { |id| !taken.include?(id) && @adapter.group(id) == group }.first(STAND_INS)
    end

    def in_order(ids)
      ids.sort_by { |id| @order.index(id) }
    end
  end
end
