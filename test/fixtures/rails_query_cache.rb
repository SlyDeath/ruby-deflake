# frozen_string_literal: true

require "minitest/autorun"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:users) { |t| t.string :name } }
# As Rails' executor does around every test
ActiveRecord::Base.connection.enable_query_cache!

class User < ActiveRecord::Base; end

class QueryCacheTest < Minitest::Test
  def test_counts_with_one_query
    queries = 0
    count = ->(*) { queries += 1 }
    ActiveSupport::Notifications.subscribed(count, "sql.active_record") { User.count }

    assert_equal 1, queries
  end
end
