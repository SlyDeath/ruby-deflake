# frozen_string_literal: true

require "minitest/autorun"

# Tests that TEST_PATH:LINE must find by their line
class AdminTest < Minitest::Test
  def test_create
    assert true
  end
end

describe "SpecStyle" do
  it "works with café" do
    _(1).must_equal 1
  end
end

class FocusTest < Minitest::Test
  def self.test(name, &) = define_method("test_#{name.gsub(/\s+/, "_")}", &)

  test "renders \"Save\" button" do
    assert true
  end

  %w[small large].each do |size|
    test "renders #{size} widget" do
      assert true
    end
  end

  def test_café
    assert true
  end

  def test_create
    assert true
  end
end
