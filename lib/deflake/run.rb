# frozen_string_literal: true

module Deflake
  # Result of a single test run, with messages about the global state it leaked.
  # group: what the error is grouped by instead of its text, when the text changes from run to run
  Run = Data.define(:seed, :passed, :error, :leaks, :group) do
    def initialize(seed:, passed:, error:, leaks: [], group: nil)
      super
    end
  end
end
