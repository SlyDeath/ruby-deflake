# frozen_string_literal: true

require "minitest/autorun"

# Two describe blocks with the same description make two classes with the same name
describe "Cart" do
  it("totals") { assert true }
end

describe "Cart" do
  it("totals") { flunk "wrong total" }
end
