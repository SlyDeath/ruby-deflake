# frozen_string_literal: true

require "minitest/autorun"
require_relative "required_tests_helper"

class RequiresTestsTest < Minitest::Test
  def test_own
    assert true
  end
end
