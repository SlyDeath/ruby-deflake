# frozen_string_literal: true

require "minitest/autorun"

# Breaks before any test whenever deflake runs a test of it alone
exit 1 if ENV["DEFLAKE_ONLY"]

class BreaksAloneTest < Minitest::Test
  def test_fails
    flunk "failed"
  end
end
