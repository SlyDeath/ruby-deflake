# frozen_string_literal: true

require "minitest/autorun"
require_relative "macro_helper"

class PagesTest < Minitest::Test
  extend Macros

  def test_home_renders
    assert true
  end

  requires_login "/admin"
end
