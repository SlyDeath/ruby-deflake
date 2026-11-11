# frozen_string_literal: true

require_relative "required_examples"

RSpec.describe "Own" do
  it("sees no global") { expect($required_examples).to be_nil }
end
