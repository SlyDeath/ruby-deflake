# frozen_string_literal: true

require "minitest/autorun"

# A failing test in a class without a name, which cannot be run on its own by name
Class.new(Minitest::Test) do
  def test_in_anonymous_class
    flunk "failed in an anonymous class"
  end
end

class PassingTest < Minitest::Test
  def test_passes
    assert true
  end
end
