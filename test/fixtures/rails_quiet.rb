# frozen_string_literal: true

require "minitest/autorun"
require "securerandom"
require "active_support"
require "active_support/test_case"
require "active_support/current_attributes"
require "active_support/current_attributes/test_helper"
require "active_support/executor"
require "active_support/executor/test_helper"
require "active_record"
require "active_record/fixtures"

# Rails cleans up after each of these tests, so none of them leaks.
# Just enough of Rails.application for ActiveSupport::Executor::TestHelper
EXECUTOR = Class.new(ActiveSupport::Executor)
EXECUTOR.to_complete { ActiveSupport::CurrentAttributes.clear_all }

module Rails
  def self.application = Application

  module Application
    def self.executor = EXECUTOR
  end
end

class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :request_id, default: -> { SecureRandom.uuid }
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:users) { |t| t.string :name } }

class User < ActiveRecord::Base; end

# What Rails 7+ does by default (executor_around_test_case)
class SignInTest < ActiveSupport::TestCase
  include ActiveSupport::Executor::TestHelper

  def test_signs_in
    Current.user = "Alice"
  end
end

# What Rails does with executor_around_test_case off
class CurrentDefaultsTest < ActiveSupport::TestCase
  include ActiveSupport::CurrentAttributes::TestHelper

  def test_reads_request_id
    refute_nil Current.request_id
  end
end

class FixturesTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails", __dir__)]
  fixtures :users

  def test_reads_fixtures
    assert_equal 2, User.count
  end

  def test_reads_fixtures_again
    assert_equal 2, User.count
  end
end
