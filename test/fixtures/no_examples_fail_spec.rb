# frozen_string_literal: true

RSpec.configure { |config| config.fail_if_no_examples = true }

RSpec.describe "Strict" do
  it("passes") { expect(1).to eq(1) }
end
