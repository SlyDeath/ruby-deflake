# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "timeout"
require "tmpdir"

module Deflake
  # Bisecting RSpec examples, in cases rspec --bisect gets wrong
  class RSpecBisectTest < Minitest::Test
    FIXTURES = File.expand_path("../fixtures", __dir__)

    # rspec --bisect would keep the polluter of the other victim and drop the one that fails itself
    def test_finds_only_the_culprit_of_this_example_even_when_it_fails_itself
      diagnoses = investigate("two_victims_spec.rb", runs: 20)

      assert_equal ["Two pollutes a and fails"], find(diagnoses, "Two victim a").culprits.names
      assert_equal ["Two pollutes b"], find(diagnoses, "Two victim b").culprits.names
    end

    def test_finds_the_culprit_with_spec_opts_set
      victim = with_env("SPEC_OPTS" => "--format documentation") do
        find(investigate("order_spec.rb", runs: 20), "Order is the victim")
      end

      assert_equal ["Order pollutes"], victim.culprits.names
    end

    # rspec --bisect waits forever for an example that takes its process down
    def test_finds_the_culprit_of_an_example_that_exits_its_process
      victim = Timeout.timeout(300) do
        find(investigate("crash_order_spec.rb", runs: 20), "Crash exits after the polluter")
      end

      assert_equal ["Crash pollutes"], victim.culprits.names
    end

    # rspec --bisect prints ids with a space unquoted for bash, which cut them short
    def test_finds_the_culprit_in_a_spec_path_with_a_space
      Dir.mktmpdir do |dir|
        path = File.join(dir, "user flows", "order_spec.rb")
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.cp(File.join(FIXTURES, "order_spec.rb"), path)

        victim = with_env("SHELL" => "/bin/bash") do
          find(Investigation.new(path, runs: 20).call, "Order is the victim")
        end

        assert_equal ["Order pollutes"], victim.culprits.names
      end
    end

    def test_reports_errors_outside_of_examples
      outside = find(investigate("outside_spec.rb", runs: 2), "errors outside of tests")

      assert_equal [2, 2], [outside.file_runs.failures, outside.file_runs.total]
      assert_equal :failed, outside.verdict
      assert_equal :stable, find(investigate("outside_spec.rb", runs: 1), "Cleanup passes").verdict
    end

    private

    def investigate(fixture, runs:)
      Investigation.new(File.join(FIXTURES, fixture), runs: runs).call
    end

    def find(diagnoses, name)
      diagnoses.find { |diagnosis| diagnosis.name == name } or flunk "#{name} not in #{diagnoses.map(&:name)}"
    end

    def with_env(values)
      old = values.keys.to_h { |name| [name, ENV.fetch(name, nil)] }
      ENV.update(values)
      yield
    ensure
      ENV.update(old)
    end
  end
end
