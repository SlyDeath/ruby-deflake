# frozen_string_literal: true

require "minitest/autorun"

# Sets up a connection around all tests of a class, as minitest-hooks' before_all does
module BeforeAll
  def run(...) # Minitest 5
    $connected = true
    super
  end

  def run_suite(...) # Minitest 6
    $connected = true
    super
  end
end

$polluted = false

class HookedTest < Minitest::Test
  extend BeforeAll

  def test_pollutes
    $polluted = true
  end

  def test_fine
    assert true
  end

  def test_victim
    assert $connected, "not connected"
    refute $polluted, "polluted by another test"
  end
end
