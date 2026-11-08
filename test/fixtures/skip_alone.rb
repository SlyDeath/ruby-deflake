# frozen_string_literal: true

require "minitest/autorun"

# The victim skips itself unless another test turned the flag on, and is broken when it is on
class SkipAloneTest < Minitest::Test
  def test_turns_flag_on
    ENV["DEFLAKE_FIXTURE_FLAG"] = "1"
  end

  def test_victim
    skip "the flag is off" unless ENV["DEFLAKE_FIXTURE_FLAG"]
    flunk "broken when the flag is on"
  end
end
