# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "active_record"
require "active_record/fixtures"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:users) { |t| t.string :name } }

class User < ActiveRecord::Base; end

# Fixtures already loaded come from the cache, with no query, as Rails' own query assertions see it
class FixtureQueriesTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails", __dir__)]
  fixtures :users

  def test_cached_fixtures_make_no_queries
    queries = []
    count = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(count, "sql.active_record") do
      ActiveRecord::FixtureSet.create_fixtures(fixture_paths, "users")
    end

    assert_empty queries
  end
end
