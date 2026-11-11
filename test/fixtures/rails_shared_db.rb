# frozen_string_literal: true

require "minitest/autorun"
require "active_record"

# One database file for every process, unless each adds its TEST_ENV_NUMBER to the name
database = ENV.fetch("DEFLAKE_FIXTURE_DB")
database += ENV.fetch("TEST_ENV_NUMBER", "") if ENV["DEFLAKE_FIXTURE_DB_PER_WORKER"]
# The timeout makes a process wait for the other one instead of failing before its first test
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: database, timeout: 10_000)
ActiveRecord::Base.connection.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY)")

class SharedDbTest < Minitest::Test
  def test_counts_users
    assert_operator ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM users"), :>=, 0
  end
end
