# frozen_string_literal: true

RSpec.configure { |config| config.fail_fast = true }

# With fail_fast, the first failure would stop the run before the victim
RSpec.describe "FailFast" do
  it("fails") { expect(1).to eq(2) }
  it("victim") { expect(1).to eq(1) }
end
