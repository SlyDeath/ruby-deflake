# frozen_string_literal: true

require "minitest/autorun"
require_relative "spec_helper"

# A Minitest::Spec file with a spec_helper and a non-ASCII name: café
describe "Helper" do
  it("works") { _(1).must_equal 1 }
end
