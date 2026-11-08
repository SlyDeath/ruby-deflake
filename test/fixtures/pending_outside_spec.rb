# frozen_string_literal: true

# An error in an after(:context) hook, and pending examples that RSpec lists in run order
RSpec.describe "Pending" do
  after(:context) { raise "hook boom" }

  it("passes") { expect(1).to eq(1) }
  5.times { |index| xit("waits #{index}") { expect(1).to eq(2) } }
end
