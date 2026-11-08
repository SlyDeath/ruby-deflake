# frozen_string_literal: true

require "minitest/autorun"

# The error message is not valid UTF-8
class BinaryErrorTest < Minitest::Test
  def test_raises_bytes
    raise (+"bad byte \xFF").force_encoding(Encoding::BINARY)
  end
end
