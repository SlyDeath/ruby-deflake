# frozen_string_literal: true

# A before(:context) hook that sets a global and never puts it back
RSpec.describe "Context" do
  before(:context) { $context_connection = "open" }

  it("passes") { expect(1).to eq(1) }
end
