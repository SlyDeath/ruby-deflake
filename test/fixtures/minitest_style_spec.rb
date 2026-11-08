# frozen_string_literal: true

require "minitest/autorun"

# A Minitest::Spec file with a _spec.rb name
describe "Thing" do
  it("passes") { _(1).must_equal 1 }
end
