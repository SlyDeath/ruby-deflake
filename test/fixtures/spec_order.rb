# frozen_string_literal: true

require "minitest/autorun"

# order.rb in Minitest::Spec style, where the class name is the describe string
$spec_polluted = false

describe "Spec order" do
  it("pollutes") { $spec_polluted = true }
  it("is fine") { _(1).must_equal 1 }
  it("is the victim") { _($spec_polluted).must_equal false }
end
