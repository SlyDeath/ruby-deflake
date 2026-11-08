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

# Loads the fixtures without a transaction and deletes them again, so the table is as it was
class NonTransactionalTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails", __dir__)]
  self.use_transactional_tests = false
  fixtures :users

  teardown { User.delete_all }

  def test_reads_fixtures
    assert_equal 2, User.count
  end

  def test_reads_fixtures_again
    assert_equal 2, User.count
  end
end
