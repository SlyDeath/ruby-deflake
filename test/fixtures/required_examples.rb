# frozen_string_literal: true

# Brought into required_examples_spec.rb with require_relative
RSpec.describe "Required" do
  it("sets the global") { $required_examples = true }
end
