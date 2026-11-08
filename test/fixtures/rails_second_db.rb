# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "active_support"
require "active_support/test_case"
require "active_record"
require "active_record/fixtures"

DIR = Dir.mktmpdir
Minitest.after_run { FileUtils.remove_entry(DIR) }

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:users) { |t| t.string :name } }

class AnimalsRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(adapter: "sqlite3", database: File.join(DIR, "animals.sqlite3"))
end

class Dog < AnimalsRecord; end

# A row that was in the second database already, and a pool not connected yet,
# as for any database the app has not queried
AnimalsRecord.connection_pool.with_connection do |connection|
  connection.create_table(:dogs) { |t| t.string :name }
  connection.execute("INSERT INTO dogs (name) VALUES ('Rex')")
end
AnimalsRecord.connection_pool.disconnect!

class ReadsDogsTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  def test_counts_dogs
    assert_equal 1, Dog.count
  end
end
