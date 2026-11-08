# frozen_string_literal: true

module Deflake
  module Execution
    # What one test process left: rows (nil when it wrote none), results of tests that cannot run
    # by name (unnamed), errors outside of tests it told about, its status and the end of its output
    Outcome = Struct.new(:rows, :unnamed, :outside, :status, :output) do
      # Failures of tests that cannot run by name, such as those in a class without a name
      def unnamed_failures = unnamed.reject { |row| row["passed"] }

      # Whether any test ran, even one that cannot run by name
      def ran? = rows.any? || unnamed.any?

      def failed_test? = rows.any? { |row| row["passed"] == false }

      def leaks = outside.flat_map { |row| row["leaks"] || [] }
    end
  end
end
