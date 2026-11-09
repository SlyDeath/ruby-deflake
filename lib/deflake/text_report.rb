# frozen_string_literal: true

module Deflake
  # Prints diagnoses in a form meant for people
  class TextReport
    VERDICTS = {
      failed: "failed, could not run it alone",
      fails_on_its_own: "fails on its own",
      order_dependent: "fails only after other tests",
      random: "fails at random, not after particular tests"
    }.freeze

    def initialize(out)
      @out = out
    end

    # Heads the tests of each file when a folder is checked
    def start(file)
      @out.puts if @started
      @started = true
      @out.puts "== #{file}"
    end

    def finish; end

    # shared: names more than one test of the file has, even tests left out of the report
    def print(diagnoses, shared: [], **)
      # Tests with the same name, such as RSpec examples from shared groups, get their ids too
      @shared_names = diagnoses.map(&:name).tally.select { |_, count| count > 1 }.keys | shared
      diagnoses.each { |diagnosis| print_diagnosis(diagnosis) }
    end

    private

    def print_diagnosis(diagnosis)
      @out.puts "#{heading(diagnosis)}: #{outcome(diagnosis)}"
      print_leaks(diagnosis.file_runs)
      return if diagnosis.verdict == :stable

      print_verdict(diagnosis)
      print_culprits(diagnosis) if diagnosis.culprits
      print_errors(diagnosis.file_runs)
      print_errors(diagnosis.isolated_runs, "alone, ") if alone_errors?(diagnosis)
    end

    def heading(diagnosis)
      @shared_names.include?(diagnosis.name) ? "#{diagnosis.name} (#{diagnosis.id})" : diagnosis.name
    end

    def print_verdict(diagnosis)
      verdict = VERDICTS.fetch(diagnosis.verdict)
      return @out.puts("  verdict: #{verdict}") unless diagnosis.isolated_runs

      @out.puts "  verdict: #{verdict} (alone: #{failed(diagnosis.isolated_runs)})"
    end

    # Errors outside of tests that only leaked failed in no run, which says nothing
    def outcome(diagnosis)
      runs = diagnosis.file_runs
      return "none in #{runs.total} runs, but leaks" if diagnosis.id == Execution::OUTSIDE && runs.failures.zero?

      failed(runs)
    end

    # Runs where the test skipped itself are not counted, but said
    def failed(summary)
      return "skipped in all #{summary.skipped} runs" if summary.total.zero?

      skipped = ", skipped in #{summary.skipped} more" if summary.skipped.positive?
      "failed #{summary.failures} of #{summary.total} runs (#{percent(summary.failure_rate)})#{skipped}"
    end

    # A rare failure is not 0%, and a failure in all but a few runs is not 100%
    def percent(rate)
      return "<1%" if rate.positive? && rate < 0.005
      return ">99%" if rate < 1 && rate >= 0.995

      "#{(rate * 100).round}%"
    end

    def print_culprits(diagnosis)
      culprits = diagnosis.culprits
      @out.puts "  #{culprit_line(culprits, diagnosis.verdict)}", "  reproduce: #{culprits.command}"
    end

    def culprit_line(culprits, verdict)
      if culprits.alone then "fails with no other test before it with this seed"
      elsif culprits.found? then "culprit: #{culprits.names.join(", ")}"
      elsif culprits.hidden
        "culprit: not found, tests in a class without a name ran too, and deflake cannot run them by name"
      elsif verdict == :random then "culprit: none, the failure did not happen again with the same seed and order"
      else "culprit: not found, the failure did not happen again with the same seed"
      end
    end

    def print_leaks(summary)
      summary.leaks.each do |leak, count|
        @out.puts "  leaks: #{leak} (#{count} of #{summary.total + summary.skipped} runs)"
      end
    end

    # Errors of the runs alone that the runs of the file did not have
    def alone_errors?(diagnosis)
      alone = diagnosis.isolated_runs
      return false unless alone&.failures&.positive?

      !(alone.errors.keys - diagnosis.file_runs.errors.keys).empty?
    end

    def print_errors(summary, prefix = "")
      errors = summary.errors
      errors = errors.except(*@printed) unless prefix.empty?
      errors.each do |error, seeds|
        @out.puts "  #{prefix}seeds #{seeds.join(", ")}:", error.to_s.gsub(/^(?=.)/, "    ")
      end
      @printed = errors.keys
    end
  end
end
