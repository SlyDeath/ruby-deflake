# frozen_string_literal: true

require "minitest/autorun"

# Classes made with Class.new that tell their own name, as some Rails test cases do
Renamed = Class.new(Minitest::Test) do
  def self.name = "DynamicTest"

  def test_passes
    assert true
  end
end

Class.new(Minitest::Test) do
  def self.name = "UnassignedTest"

  def test_passes
    assert true
  end
end
