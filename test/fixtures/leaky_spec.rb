# frozen_string_literal: true

# The RSpec twin of leaky.rb
RSpec.describe "Leaky" do
  it "sets env" do
    ENV["DEFLAKE_FIXTURE_LEAK"] = "1"
  end

  it "sets a global" do
    $deflake_fixture_leak = true
  end

  it "cleans up" do
    ENV["DEFLAKE_FIXTURE_TEMP"] = "1"
    ENV.delete("DEFLAKE_FIXTURE_TEMP")
  end
end
