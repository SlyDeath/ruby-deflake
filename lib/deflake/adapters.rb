# frozen_string_literal: true

require "rbconfig"
require_relative "adapters/minitest"
require_relative "adapters/rspec"

module Deflake
  # Each adapter builds the command that runs a test file with deflake's recorder loaded
  module Adapters
    # Minitest itself, a helper named after it such as minitest_helper, or its expectations: _(x).must_equal
    MINITEST = /minitest|mini_test|\b_\(.*\)\.(?:must|wont)_/i

    module_function

    # Minitest::Spec files are often named *_spec.rb too, so a spec file is sent to
    # Minitest when it mentions Minitest and neither RSpec nor rails_helper. A spec_helper
    # says nothing: Minitest::Spec projects use one as well
    def for(path)
      return Minitest unless path.to_s.end_with?("_spec.rb")

      # Read as UTF-8 whatever the locale, as Ruby reads the test file itself
      source = File.read(path, mode: "r:UTF-8").scrub
      source.match?(MINITEST) && !source.match?(/\bRSpec\b|rails_helper/) ? Minitest : RSpec
    rescue SystemCallError
      RSpec
    end
  end
end
