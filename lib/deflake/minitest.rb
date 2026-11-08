# frozen_string_literal: true

require_relative "minitest_reporter"

if Gem::Version.new(Minitest::VERSION) < Gem::Version.new("5.11")
  abort "deflake needs Minitest 5.11 or newer, this is #{Minitest::VERSION}"
end

module Minitest
  # Minitest calls this at startup because the "deflake" plugin is registered
  # below. Does nothing unless deflake started this process
  def self.plugin_deflake_init(options)
    path = ENV.delete(Deflake::ResultFile::ENV_KEY) or return

    if ENV.delete(Deflake::ResultFile::LIST_KEY)
      Deflake::MinitestTests.list(path)
      # Only listing was asked for, so Minitest itself runs nothing.
      # A string, because Minitest 5 cannot take a Regexp here
      return options[:exclude] = "/./"
    end

    # Minitest still runs the tests itself, so class-level hooks and other plugins work as usual
    ids = Deflake::MinitestTests.requested
    Deflake::MinitestTests.run_only(ids) if ids
    reporter << Deflake::MinitestReporter.new(path, options[:seed])
  end
end

if ENV.key?(Deflake::ResultFile::ENV_KEY)
  # Before the test file loads, so a test that a macro defines is found at the line that calls it
  list = ENV.fetch(Deflake::ResultFile::LIST_KEY, nil)
  Deflake::MinitestTests.watch_declarations(list) if list
  Minitest::Runnable.singleton_class.prepend(Deflake::MinitestTests::ClassLeaks)
end

# Minitest 5 loads the plugins of other gems only while no plugin is registered, so load them first
Minitest.load_plugins if Minitest::VERSION.to_i < 6 && !ENV["MT_NO_PLUGINS"] && !ARGV.include?("--no-plugins")
Minitest.extensions << "deflake" unless Minitest.extensions.include?("deflake")
