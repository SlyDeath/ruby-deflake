# frozen_string_literal: true

require "minitest/autorun"

# A test class without a name, which cannot be run on its own by name
Class.new(Minitest::Test) do
  def test_in_anonymous_class
    assert true
  end
end

class NamedTest < Minitest::Test
  def test_named
    assert true
  end
end
