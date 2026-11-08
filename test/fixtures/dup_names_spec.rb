# frozen_string_literal: true

# Two different examples with the same description
RSpec.shared_examples "positive" do |number|
  it("is positive") { expect(number).to be > 0 }
end

RSpec.describe "Num" do
  it_behaves_like "positive", 1
  it_behaves_like "positive", -1
end
