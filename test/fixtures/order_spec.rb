# frozen_string_literal: true

# One example breaks another, but only when it happens to run first
$polluted = false

RSpec.describe "Order" do
  it("is fine") { expect(true).to be(true) }
  it("is also fine") { expect(true).to be(true) }
  it("pollutes") { $polluted = true }
  it("is fine as well") { expect(true).to be(true) }
  it("is the victim") { expect($polluted).to be(false) }
end
