# frozen_string_literal: true

require "minitest/autorun"

# A test that leaks and then skips itself
class SkipLeakTest < Minitest::Test
  def test_sets_env_then_skips
    ENV["DEFLAKE_FIXTURE_SKIP_LEAK"] = "1"
    skip "later"
  end
end
