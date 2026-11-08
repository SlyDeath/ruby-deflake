# frozen_string_literal: true

require "test_helper"

class DeflakeTest < Minitest::Test
  def test_has_a_version_number
    refute_nil Deflake::VERSION
  end
end
