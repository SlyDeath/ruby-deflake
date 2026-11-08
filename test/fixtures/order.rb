# frozen_string_literal: true

require "minitest/autorun"

# One test breaks another, but only when it happens to run first
$polluted = false

class OrderTest < Minitest::Test
  def test_fine
    assert true
  end

  def test_also_fine
    assert true
  end

  def test_pollutes
    $polluted = true
  end

  def test_fine_as_well
    assert true
  end

  def test_victim
    refute $polluted, "polluted by another test"
  end
end
