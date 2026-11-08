# frozen_string_literal: true

# One error after a group, whose progress line changes with the order of the groups
RSpec.describe "Seeding" do
  after(:context) { raise "could not seed the database after 5 seconds" }

  it("works") { expect(1).to eq(1) }
end

RSpec.describe "Other" do
  it("one") { expect(1).to eq(1) }
  it("two") { expect(1).to eq(1) }
  it("three") { expect(1).to eq(1) }
end
