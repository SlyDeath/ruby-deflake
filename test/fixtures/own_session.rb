# frozen_string_literal: true

require "minitest/autorun"

# deflake starts each test process in a session of its own, away from the terminal
class OwnSessionTest < Minitest::Test
  def test_leads_its_session
    assert_equal Process.pid, Process.getsid
  end

  def test_sees_no_variables_meant_for_deflake
    assert_empty(ENV.keys.grep(/\ADEFLAKE_(?:OUTPUT|ONLY|ORDER|LIST)\z/))
    refute defined?(JSON), "deflake loaded json into the test process"
  end
end
