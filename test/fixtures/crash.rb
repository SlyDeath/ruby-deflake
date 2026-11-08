# frozen_string_literal: true

require "minitest/autorun"

# test_dies takes the whole process down whenever test_first ran before it
class CrashTest < Minitest::Test
  @@first_ran = false # rubocop:disable Style/ClassVars

  def test_first
    @@first_ran = true # rubocop:disable Style/ClassVars
  end

  def test_dies
    exit!(1) if @@first_ran

    assert true
  end
end
