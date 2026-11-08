# frozen_string_literal: true

# The RSpec twin of sample.rb
RSpec.describe "Sample" do
  it "passes" do
    expect(1).to eq(1)
  end

  it "fails" do
    expect(1).to eq(2)
  end

  it "is pending" do
    pending "not ready"
    raise "boom"
  end
end
