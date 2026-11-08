# frozen_string_literal: true

require "minitest/autorun"

# Starts a process that outlives the test and keeps its output open
class BackgroundTest < Minitest::Test
  def test_starts_a_server
    Process.detach(spawn("sleep", "5"))
    assert true
  end
end
