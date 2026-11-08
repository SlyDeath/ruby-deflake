# frozen_string_literal: true

require "minitest/autorun"

# A test whose name is not ASCII, as Rails' test "..." gives for many languages
class UnicodeTest < Minitest::Test
  def test_проверка
    assert true
  end
end
