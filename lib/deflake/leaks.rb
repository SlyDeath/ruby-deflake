# frozen_string_literal: true

require_relative "leaks/env"
require_relative "leaks/clock"
require_relative "leaks/globals"
require_relative "leaks/cache"
require_relative "leaks/current"
require_relative "leaks/rows"
require_relative "leaks/jobs"

module Deflake
  # Global state a test changed and did not put back. Every detector has two methods:
  # snapshot returns the current state (nil when it does not apply), and
  # diff(before, after) returns one message per leak. Add your own in test_helper:
  #
  #   Deflake::Leaks.detectors << MyDetector.new
  module Leaks
    module_function

    def detectors
      @detectors ||= [Env, Clock, Globals, Cache, Current, Rows, Jobs].map(&:new)
    end

    def snapshot
      detectors.to_h { |detector| [detector, quietly { detector.snapshot }] }
    end

    def since(snapshot)
      snapshot.flat_map do |detector, before|
        next [] if before.nil?

        after = quietly { detector.snapshot }
        after.nil? ? [] : quietly { detector.diff(before, after) } || []
      end
    end

    # Whether a constant is there without loading it: asking for an autoloaded class such as
    # ActiveRecord::Base would load it inside a test, and run the hooks that wait for it there
    def loaded?(namespace, name)
      namespace.const_defined?(name, false) && !namespace.autoload?(name)
    end

    # Leaks of a group of tests that are not just its tests' leaks added up: "2 jobs" after two
    # tests that each left "1 job" is the same leak, and so are two new cache keys after two tests
    # that each left one
    def own(leaks, of_tests)
      kinds = of_tests.map { |leak| kind(leak) }
      leaks.reject { |leak| kinds.include?(kind(leak)) }
    end

    # What a leak is about, without its count and the list after a colon. A number inside a name,
    # as in $retry2, stays
    def kind(leak)
      leak.sub(/:\s.*\z/m, "").sub(/\b\d+\b.*\z/m) { |rest| rest.gsub(/\b\d+\b/, "N").gsub(/s\b/, "") }
    end

    # A broken detector must never break the tests it watches. NotImplementedError
    # (an adapter without some SQL) is a ScriptError, and a too deep structure raises
    # a SystemStackError, neither of them a StandardError
    def quietly
      yield
    rescue StandardError, ScriptError, SystemStackError
      nil
    end
  end
end
