# frozen_string_literal: true

module Deflake
  # Everything deflake found out about one test.
  # isolated_runs and culprits are nil when there was nothing to investigate,
  # and isolated_runs also when the failure could not run alone: errors outside of tests,
  # or a test whose runs alone all broke before it started
  Diagnosis = Data.define(:name, :id, :file_runs, :isolated_runs, :culprits) do
    # :stable, :failed (could not run alone), :fails_on_its_own, :order_dependent, or :random:
    # it passed every time alone, and the failure did not happen again with the same seed and order,
    # with every test of the file that ran before it
    def verdict
      return :stable if file_runs.failures.zero?
      return :failed if isolated_runs.nil?
      return :fails_on_its_own if fails_alone?

      culprits.nil? || culprits.found? || culprits.hidden ? :order_dependent : :random
    end

    # It failed in a run alone, or with no test before it in a bisect
    def fails_alone?
      isolated_runs.failures.positive? || culprits&.alone || false
    end

    # Nothing failed and nothing leaked
    def clean?
      verdict == :stable && file_runs.leaks.empty?
    end
  end
end
