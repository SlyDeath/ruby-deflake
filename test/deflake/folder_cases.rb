# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"
require "json"

module Deflake
  # Test folders for the tests of a folder given as the test path
  module FolderCases
    PASSES = <<~RUBY
      require "minitest/autorun"

      class %<name>s < Minitest::Test
        def test_passes = assert(true)
      end
    RUBY
    FAILS = <<~RUBY
      require "minitest/autorun"

      class FailsTest < Minitest::Test
        def test_fails = assert_equal(2, 1)
      end
    RUBY
    SKIPS = <<~RUBY
      require "minitest/autorun"

      class SkipsTest < Minitest::Test
        def test_skips = skip("later")
      end
    RUBY
    SPEC = <<~RUBY
      RSpec.describe "Nested" do
        it("passes") { expect(1).to eq(1) }
      end
    RUBY

    # Fixtures named *_test.rb would run with the suite itself, so they are written here
    def setup
      @folder = Dir.mktmpdir("deflake-folder")
    end

    def teardown
      FileUtils.remove_entry(@folder)
    end

    def write_nested
      write("models/user_test.rb", format(PASSES, name: "UserTest"))
      write("a/b/nested_spec.rb", SPEC)
      write("support/helper.rb", "raise 'not a test file'")
    end

    def write_mixed
      write("broken_test.rb", "require 'missing_helper'")
      write("fails_test.rb", FAILS)
      write("passes_test.rb", format(PASSES, name: "PassesTest"))
    end

    def write(name, source)
      path = File.join(@folder, name)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, source)
    end

    def run_cli(*argv)
      out = StringIO.new
      err = StringIO.new
      status = CLI.new(argv, out: out, err: err).run
      [status, out.string, err.string]
    end
  end
end
