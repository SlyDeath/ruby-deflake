# frozen_string_literal: true

module Deflake
  # Investigates a test file, or every test file under a folder, and prints the report.
  # Returns the exit code: 0 when nothing was found, 1 when something was, 2 when tests could not run
  class Check
    PATTERN = "**/*_{test,spec}.rb"

    def initialize(report, err:, runs:, jobs:)
      @report = report
      @err = err
      @runs = runs
      @jobs = jobs
    end

    def file(path, line)
      finished { investigate(path, line) }
    end

    # The files run one after another. A file that cannot run does not stop the others
    def folder(path)
      files = Dir.glob(PATTERN, base: path).sort.map { |file| File.join(path, file) }.select { |file| File.file?(file) }
      raise Error, "no test files (*_test.rb or *_spec.rb) in #{path}" if files.empty?

      codes = finished { files.to_h { |file| [file, investigate_in_folder(file)] } }
      summarize(codes)
      codes.values.max
    end

    private

    def finished
      result = yield
      output { @report.finish }
      result
    end

    def investigate_in_folder(file)
      output { @report.start(file) }
      investigate(file, nil)
    rescue Error => e
      @err.puts "deflake: #{e.message}"
      2
    end

    def investigate(path, line)
      investigation = Investigation.new(path, line: line, runs: @runs, jobs: @jobs)
      diagnoses = investigation.call
      report(path, diagnoses, line, investigation)
    end

    # A test on the line that never started is an error: something stopped every run before it,
    # or the file's own filters leave it out
    def report(path, diagnoses, line, investigation)
      not_run = investigation.not_run
      if not_run.any?
        @err.puts "deflake: #{not_run.join(", ")} never ran in a run of the whole file " \
                  "(a filter of the file leaves it out, or something stops every run before it)"
      end
      # As with a plain run, tests that all skipped themselves are not an error
      @err.puts "deflake: #{skipped(line)}, nothing to report" if diagnoses.empty? && not_run.empty?
      output { @report.print(diagnoses, file: path, not_run: not_run, shared: investigation.shared_names) }
      diagnoses.all?(&:clean?) && not_run.empty? ? 0 : 1
    end

    # A reader that stops early, such as head, is not an error of deflake's
    def output
      yield
    rescue Errno::EPIPE
      nil
    end

    def skipped(line)
      line ? "the test at line #{line} skipped itself in every run" : "every test skipped itself"
    end

    def summarize(codes)
      files = codes.keys.group_by { |file| codes[file] }
      summary = ["checked #{codes.size} files"]
      summary << "failing or leaking tests in #{files[1].join(", ")}" if files[1]
      summary << "could not check #{files[2].join(", ")}" if files[2]
      summary << "nothing found" if summary.one?
      @err.puts "deflake: #{summary.join("; ")}"
    end
  end
end
