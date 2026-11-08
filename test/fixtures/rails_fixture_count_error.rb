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

# An adapter that cannot list its tables, which loading fixtures does not need
ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(Module.new { def tables = raise(NotImplementedError) })

class FixturesTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails", __dir__)]
  fixtures :users

  def test_reads_fixtures
    assert_equal 2, User.count
  end
end
