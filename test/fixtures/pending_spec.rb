# frozen_string_literal: true

RSpec.describe "Pending" do
  it "fails as expected" do
    pending "broken"
    expect(1).to eq(2)
  end

  it("is skipped") { skip "later" }
end
