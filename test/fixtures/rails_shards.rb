# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "active_support"
require "active_support/test_case"
require "active_record"

DIR = Dir.mktmpdir
Minitest.after_run { FileUtils.remove_entry(DIR) }

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# A model whose rows live in two shards
class ShardRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to shards: {
    default: { writing: { adapter: "sqlite3", database: File.join(DIR, "default.sqlite3") } },
    one: { writing: { adapter: "sqlite3", database: File.join(DIR, "one.sqlite3") } }
  }
end

class Event < ShardRecord; end

%i[default one].each do |shard|
  ShardRecord.connected_to(shard: shard) do
    ShardRecord.connection.create_table(:events) { |t| t.string :name }
  end
end

class ShardTest < ActiveSupport::TestCase
  def test_leaves_a_row_in_another_shard
    ShardRecord.connected_to(shard: :one) { Event.create!(name: "left") }
  end
end
