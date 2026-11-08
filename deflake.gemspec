# frozen_string_literal: true

require_relative "lib/deflake/version"

Gem::Specification.new do |spec|
  spec.name = "deflake"
  spec.version = Deflake::VERSION
  spec.authors = ["Roman Belyaev"]
  spec.email = ["slyrs@yandex.ru"]

  spec.summary = "Find flaky tests in Minitest and RSpec and explain why they fail."
  spec.description = <<~DESC
    deflake runs a suspicious test many times, measures how often it fails,
    tells apart failures that happen on their own from failures caused by test
    order, finds the tests that cause them, and detects global state that tests
    leave behind: ENV, the clock, globals, Rails.cache, Current attributes,
    database rows and enqueued jobs.
  DESC
  spec.homepage = "https://github.com/SlyDeath/ruby-deflake"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Only these files are packaged into the gem
  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["deflake"]
  spec.require_paths = ["lib"]
end
