# frozen_string_literal: true

require "minitest/autorun"

# A class-level hook that reports its error as a result, as minitest-hooks' before_all does
module FailingBeforeAll
  # Minitest 6 runs a class with run_suite, and its run runs a single test
  define_method(Minitest::VERSION.start_with?("5.") ? :run : :run_suite) do |reporter, *rest|
    hook_failed(reporter)
    super(reporter, *rest)
  end

  def hook_failed(reporter)
    hook = new("before_all")
    hook.failures << Minitest::UnexpectedError.new(RuntimeError.new("before_all broke"))
    reporter.record Minitest::Result.from(hook)
  end
end

class HookTest < Minitest::Test
  extend FailingBeforeAll

  def test_passes
    assert true
  end
end
