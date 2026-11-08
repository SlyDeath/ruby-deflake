# frozen_string_literal: true

require "minitest/autorun"

# A test that never finishes, as a deadlock would
class HangTest < Minitest::Test
  def test_hangs
    File.write(File.join(ENV["DEFLAKE_FIXTURE_PIDS"], Process.pid.to_s), "") if ENV["DEFLAKE_FIXTURE_PIDS"]
    sleep 60
  end
end
