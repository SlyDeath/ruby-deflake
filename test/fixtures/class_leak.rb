# frozen_string_literal: true

require "minitest/autorun"

# A class-level hook that sets a global and never puts it back, as minitest-hooks' before_all
# may: it runs around the tests of the class, in with_info_handler
module SetsUpOnce
  def with_info_handler(*, &)
    $connection = "open"
    super
  end
end

class ClassLeakTest < Minitest::Test
  extend SetsUpOnce

  def test_passes
    assert true
  end
end
