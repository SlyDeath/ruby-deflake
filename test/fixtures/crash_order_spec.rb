# frozen_string_literal: true

# The victim takes its process down, but only after the polluter
RSpec.describe "Crash" do
  it("pollutes") { $deflake_crash = true }

  it("exits after the polluter") do
    exit!(3) if $deflake_crash
    expect(1).to eq(1)
  end
end
