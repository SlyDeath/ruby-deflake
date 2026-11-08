# frozen_string_literal: true

# An exception whose message is nil, next to an example that passes
class SilentError < StandardError
  def message = nil
end

RSpec.describe "Silent" do
  it("raises") { raise SilentError }
  it("passes") { expect(1).to eq(1) }
end
