# frozen_string_literal: true

require "minitest/autorun"

# As a test fails when another process holds the same SQLite database
class LockedTest < Minitest::Test
  def test_writes
    raise "SQLite3::BusyException: database is locked"
  end
end
