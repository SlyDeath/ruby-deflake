# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "active_record"
require "active_record/fixtures"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title }
  create_table(:tags) { |t| t.string :name }
  create_table(:posts_tags, id: false) { |t| t.integer :post_id, :tag_id }
  create_table(:comments) { |t| t.string :body }
end

class Post < ActiveRecord::Base
  has_and_belongs_to_many :tags
end

class Tag < ActiveRecord::Base; end
class Comment < ActiveRecord::Base; end

# Fixtures with has_and_belongs_to_many also fill the join table, which is no fixture set of its own
class HabtmTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails_habtm", __dir__)]
  fixtures :posts, :tags

  def test_reads_tags
    assert_equal ["Ruby"], Post.first.tags.map(&:name)
  end
end

# A second load in setup, for a set the class does not declare
class SecondLoadTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("rails_habtm", __dir__)]
  fixtures :posts

  setup { ActiveRecord::FixtureSet.create_fixtures(fixture_paths.first, "comments") }

  def test_reads_comments
    assert_equal 1, Comment.count
  end
end
