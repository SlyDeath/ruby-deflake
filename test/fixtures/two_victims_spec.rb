# frozen_string_literal: true

# Two victims with their own polluters; the polluter of the first one fails itself
RSpec.describe "Two" do
  it("pollutes a and fails") do
    $deflake_two_a = true
    expect(1).to eq(2)
  end

  it("pollutes b") { $deflake_two_b = true }
  it("victim a") { expect($deflake_two_a).to be_nil }
  it("victim b") { expect($deflake_two_b).to be_nil }
end
