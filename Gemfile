# frozen_string_literal: true

source "https://rubygems.org"

# Runtime dependencies come from deflake.gemspec
gemspec

# Development tools only
gem "irb"
gem "rake", "~> 13.0"

gem "minitest", ENV.fetch("MINITEST_VERSION", ">= 5.16")
gem "rspec", "~> 3.13"

# Only for testing the Rails leak detectors
gem "activejob", require: false
gem "activerecord", require: false
gem "sqlite3", require: false

# Coverage report for Codecov, only with COVERAGE set
gem "simplecov", require: false
gem "simplecov-cobertura", require: false

# Pinned to a minor version: a new cop in a newer release must not turn CI red on its own
gem "rubocop", "~> 1.92.0", require: false
gem "rubocop-minitest", "~> 0.41.0", require: false
gem "rubocop-rake", "~> 0.7.1", require: false
