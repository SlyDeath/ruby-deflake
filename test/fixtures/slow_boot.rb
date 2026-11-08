# frozen_string_literal: true

require "minitest/autorun"

# Boots for longer than any timeout the tests give it
sleep 30

class SlowBootTest < Minitest::Test
  def test_passes
    assert true
  end
end
