# frozen_string_literal: true

require "minitest/autorun"

# Every test is in a class without a name, and they all pass
Class.new(Minitest::Test) do
  def test_passes
    assert true
  end
end
