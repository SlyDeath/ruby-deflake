# frozen_string_literal: true

require "minitest/autorun"

# The test that breaks the victim is in a class without a name, which no order can name
Class.new(Minitest::Test) do
  def test_pollutes
    $anonymous_flag = true
  end
end

class AnonymousVictimTest < Minitest::Test
  def test_victim
    refute $anonymous_flag
  end
end
