# frozen_string_literal: true

require "minitest/autorun"
require "active_record"
require "active_job"
require "active_support/cache"
require "active_support/current_attributes"

# Just enough of a Rails app for the Rails leak detectors
module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

class Current < ActiveSupport::CurrentAttributes
  attribute :user
end

class NoopJob < ActiveJob::Base
  def perform; end
end

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(nil)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:users) { |t| t.string :name } }

class User < ActiveRecord::Base; end

# A second database
class AnimalsRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(adapter: "sqlite3", database: ":memory:")
end
AnimalsRecord.connection.create_table(:dogs) { |t| t.string :name }

class Dog < AnimalsRecord; end

class RailsLeakyTest < Minitest::Test
  def test_leaves_a_row
    User.create!(name: "left behind")
  end

  def test_leaves_a_dog
    Dog.create!(name: "Rex")
  end

  def test_rolls_back_its_row
    ActiveRecord::Base.transaction do
      User.create!(name: "rolled back")
      raise ActiveRecord::Rollback
    end
  end

  def test_fills_cache
    Rails.cache.write("users/1", "Alice")
  end

  def test_sets_current
    Current.user = "Alice"
  end

  def test_enqueues_a_job
    NoopJob.perform_later
  end
end
