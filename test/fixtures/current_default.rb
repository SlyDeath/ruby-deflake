# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "active_support/current_attributes"
require "active_support/testing/time_helpers"

# The default is computed the first time the test reads it, inside travel_to
class Current < ActiveSupport::CurrentAttributes
  attribute :started_at, default: -> { Time.now }
end

class StartedAtTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  def test_started_at_follows_travel
    moment = Time.utc(2020, 1, 1)
    travel_to(moment) { assert_equal moment, Current.started_at }
  end
end
