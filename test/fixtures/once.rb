# frozen_string_literal: true

require "minitest/autorun"

# The victim fails the first time it runs in a whole test of deflake, and never again,
# as a test that fails at random does now and then
class OnceTest < Minitest::Test
  def test_a
    assert true
  end

  def test_b
    assert true
  end

  def test_victim
    marker = ENV.fetch("DEFLAKE_FIXTURE_ONCE")
    return if File.exist?(marker)

    File.write(marker, "")
    flunk "failed once"
  end
end
