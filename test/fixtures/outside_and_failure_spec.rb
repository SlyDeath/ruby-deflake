# frozen_string_literal: true

# An error outside of examples in a run where an example fails too
RSpec.describe "Both" do
  after(:context) { raise "hook boom" }

  it("fails") { expect(1).to eq(2) }
end
