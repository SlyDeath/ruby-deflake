# frozen_string_literal: true

require "minitest/autorun"

# Runs only somewhere else
class AllSkippedTest < Minitest::Test
  def test_only_on_ci
    skip "runs only on CI"
  end
end
