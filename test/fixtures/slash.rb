# frozen_string_literal: true

require "minitest/autorun"

# Minitest reads a name with two slashes as a regexp: /users/ matches both tests
$users_polluted = false

class SlashTest < Minitest::Test
  define_method("test_GET_/users/1_works") { refute $users_polluted }

  def test_pollutes_users
    $users_polluted = true
  end
end
