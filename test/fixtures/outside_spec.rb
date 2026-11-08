# frozen_string_literal: true

# Every example passes, but the cleanup after them fails
RSpec.describe "Cleanup" do
  after(:context) { raise "cleanup failed" }

  it("passes") { expect(1).to eq(1) }
end
