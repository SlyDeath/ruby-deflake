# frozen_string_literal: true

# order_spec.rb plus an example that always fails, which is nobody's culprit
$noisy_polluted = false

RSpec.describe "Noisy" do
  it("is fine") { expect(true).to be(true) }
  it("pollutes") { $noisy_polluted = true }
  it("always fails") { expect(1).to eq(2) }
  it("is the victim") { expect($noisy_polluted).to be(false) }
end
