# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "active_record"

# An application whose writing role is not called :writing
ActiveRecord.writing_role = :primary
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:users) { |t| t.string :name } }

class User < ActiveRecord::Base; end

class WritingRoleTest < ActiveSupport::TestCase
  def test_leaves_a_row
    User.create!(name: "left behind")
  end
end
