# frozen_string_literal: true

require "minitest/autorun"

# A failure in a class without a name, next to a failing test that has one
Class.new(Minitest::Test) do
  def test_in_anonymous_class
    flunk "failed in an anonymous class"
  end
end

class NamedFailingTest < Minitest::Test
  def test_fails
    flunk "failed in a named class"
  end
end
