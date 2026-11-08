# frozen_string_literal: true

module Deflake
  # Summary of all runs of a single test
  class Summary
    # How to run only this test: "Class#test_name" or an RSpec example id
    attr_reader :id
    # Readable test name
    attr_reader :name
    # In how many runs the test skipped itself; those runs are not in total
    attr_reader :skipped

    # skipped_leaks: leaks of the runs where the test skipped itself
    def initialize(runs, id: nil, name: id, skipped: 0, skipped_leaks: [])
      @runs = runs
      @id = id
      @name = name
      @skipped = skipped
      @skipped_leaks = skipped_leaks
    end

    def total
      @runs.size
    end

    def failures
      @runs.count { |run| !run.passed }
    end

    def failure_rate
      total.zero? ? 0.0 : failures.fdiv(total)
    end

    # Messages that differ only in the addresses inside inspected objects ("#<User:0x000055...>"),
    # which change in every process, are one error. Other hexadecimal numbers are kept. Runs with
    # a group, such as a crash whose output depends on the seed, show the error of the first one
    def errors
      groups = @runs.reject(&:passed).group_by { |run| run.group || normalize(run.error) }.values
      groups.each_with_object({}) do |runs, all|
        (all[normalize(runs.first.error)] ||= []).concat(runs.map(&:seed))
      end
    end

    # Leak message => in how many runs it happened, skipped runs included
    def leaks
      (@runs.flat_map(&:leaks) + @skipped_leaks).tally
    end

    private

    def normalize(message)
      message&.gsub(/(#<(?:[A-Z]\w*::)*[^\s>:]+:)0x\h{8,16}/, '\10x...')
    end
  end
end
