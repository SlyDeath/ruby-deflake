# frozen_string_literal: true

# A run of this group stops at its first failure, and a nested group takes the process down
RSpec.configure { |config| config.fail_fast = true }

RSpec.describe "Group" do
  it("fails") { expect(1).to eq(2) }
  it("passes") { expect(1).to eq(1) }

  describe "nested" do
    before(:context) { exit! 3 }

    it("exits") { expect(1).to eq(1) }
  end
end
