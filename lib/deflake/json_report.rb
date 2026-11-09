# frozen_string_literal: true

require "json"

module Deflake
  # Prints diagnoses as JSON for CI and other tools. The format may change before 1.0
  class JsonReport
    def initialize(out, err: nil)
      @out = out
      @err = err
      @objects = []
    end

    # Nothing is printed until the end, so the progress goes to stderr
    def start(file, number, total)
      @err&.puts "deflake: checking #{file} (#{number} of #{total})"
    end

    def not_checked(file, message)
      @objects << { file: file, **never_ran(file), verdict: :not_checked,
                    errors: [{ message: message, seeds: [] }] }
    end

    def flush
      @out.flush if @out.respond_to?(:flush)
    end

    # not_run: ids of tests on the line that never started, each one an object with the verdict "not_run"
    def print(diagnoses, file: nil, not_run: [], **)
      objects = diagnoses.map { |diagnosis| as_json(diagnosis) } + not_run.map { |id| never_ran(id) }
      objects = objects.map { |object| { file: file, **object } } if file
      @objects.concat(objects)
    end

    # One array for every file, printed at the end
    def finish
      # Names and paths in another encoding, as under LANG=C, would stop the generator
      @out.puts JSON.pretty_generate(ResultFile.clean(@objects))
    end

    private

    def as_json(diagnosis)
      runs = diagnosis.file_runs
      { name: diagnosis.name, id: diagnosis.id, verdict: diagnosis.verdict,
        runs: counts(runs), isolated_runs: diagnosis.isolated_runs && counts(diagnosis.isolated_runs),
        errors: runs.errors.map { |message, seeds| { message: message, seeds: seeds } },
        leaks: runs.leaks.map { |message, count| { message: message, runs: count } },
        culprits: diagnosis.culprits&.to_h }
    end

    def never_ran(id)
      { name: id, id: id, verdict: :not_run, runs: counts(Summary.new([], id: id)), isolated_runs: nil,
        errors: [], leaks: [], culprits: nil }
    end

    def counts(summary)
      # Not rounded: one failure in thousands of runs is not 0
      { total: summary.total, failures: summary.failures, failure_rate: summary.failure_rate,
        skipped: summary.skipped }
    end
  end
end
