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

# Fixtures loaded in a transaction stay in the table for the next class
class ATransactionalTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails", __dir__)]
  fixtures :users

  def test_loads_fixtures
    assert User.table_exists?
  end
end

# Without a transaction every test loads the fixtures again and adds a row it leaves
class BLeakyTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails", __dir__)]
  self.use_transactional_tests = false
  fixtures :users

  i_suck_and_my_tests_are_order_dependent!

  def test_a_leaks
    User.create!(name: "left behind")
  end

  def test_b_leaks
    User.create!(name: "left behind")
  end
end

# Cleans up what it loaded, after a class whose fixtures were already in the table
class CCleanTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails", __dir__)]
  self.use_transactional_tests = false
  fixtures :users

  teardown { User.delete_all }

  def test_reads_fixtures
    assert_equal 2, User.count
  end
end
