# frozen_string_literal: true

require "minitest/autorun"

# The test always fails in a run of the whole file. Run alone, a class-level hook breaks first
# and reports its error as a result, as minitest-hooks' before_all does, and no test runs
ALONE = ENV.key?("DEFLAKE_ONLY")

module BreaksAlone
  define_method(Minitest::VERSION.start_with?("5.") ? :run : :run_suite) do |reporter, *rest|
    return super(reporter, *rest) unless ALONE

    hook = new("before_all")
    hook.failures << Minitest::UnexpectedError.new(RuntimeError.new("before_all broke"))
    reporter.record Minitest::Result.from(hook)
    []
  end
end

class BreaksAloneTest < Minitest::Test
  extend BreaksAlone

  def test_fails
    flunk "always"
  end
end
