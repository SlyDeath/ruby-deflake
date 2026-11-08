# frozen_string_literal: true

require "rspec/core"
require_relative "result_file"

module Deflake
  # Writes the result of every example to a file, one JSON line per example
  class RSpecFormatter
    ::RSpec::Core::Formatters.register self, :start, :example_started, :example_passed, :example_failed,
                                       :example_pending

    # Failures of expectations, whose message says it all, as Minitest's assertions do
    EXPECTATIONS = %w[RSpec::Expectations::ExpectationNotMetError
                      RSpec::Expectations::MultipleExpectationsNotMetError
                      RSpec::Mocks::MockExpectationError].freeze

    class << self
      # Where to write, taken from the environment before the tests can see it
      attr_accessor :path

      # Every leak the examples reported so far
      def reported
        @reported ||= []
      end

      # An error outside of examples, such as in an after(:context) hook: its class and message
      # without the backtrace, which would split one error into many
      def outside(context, exception)
        ResultFile.append(path, outside: "#{context}\n#{describe(exception)}")
      rescue StandardError
        nil
      end

      def group_leaks(group, leaks)
        ResultFile.append(path, outside: nil, leaks: leaks.map { |leak| "#{group}, outside its examples: #{leak}" })
      end

      # The class too, so errors of two classes with one message are not one error. The message
      # may be anything an exception class returns, nil included
      def describe(exception)
        message = exception.message.to_s.strip
        EXPECTATIONS.include?(exception.class.name) ? message : "#{exception.class}: #{message}"
      rescue StandardError, ScriptError
        exception.class.name.to_s
      end
    end

    def initialize(_output)
      @path = self.class.path
    end

    # The file exists once RSpec starts, so a run where no example wrote a line still tells that
    # the process got going
    def start(_notification)
      ResultFile.start(@path)
    end

    def example_started(notification)
      ResultFile.append(@path, started: notification.example.id, name: notification.example.full_description)
    end

    def example_passed(notification)
      record(notification.example, nil)
    end

    def example_failed(notification)
      record(notification.example, self.class.describe(notification.example.exception))
    end

    # An example marked pending that failed as expected passed: its run counts.
    # One that skip or xit left out is skipped, and only its leaks count
    def example_pending(notification)
      example = notification.example
      return record(example, nil) unless example.execution_result.example_skipped?

      ResultFile.append(@path, id: example.id, name: example.full_description, skipped: true,
                               seed: ::RSpec.configuration.seed, leaks: leaks(example))
    end

    private

    def record(example, error)
      ResultFile.append(@path, id: example.id, name: example.full_description, passed: error.nil?,
                               seed: ::RSpec.configuration.seed, error: error, leaks: leaks(example))
    end

    def leaks(example)
      (example.metadata[:deflake_leaks] || []).tap { |leaks| self.class.reported.concat(leaks) }
    end
  end
end
