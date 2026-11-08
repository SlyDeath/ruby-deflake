# frozen_string_literal: true

require "tmpdir"

# Breaks before its first example once for every process that runs deflake, as a
# database that is not ready yet would
marker = File.join(Dir.tmpdir, "deflake-fixture-suite-#{Process.ppid}")

RSpec.configure do |config|
  config.before(:suite) do
    next if File.exist?(marker)

    File.write(marker, "")
    raise "database not ready"
  end
end

RSpec.describe "Suite" do
  it("passes") { expect(1).to eq(1) }
end
