# frozen_string_literal: true

module Deflake
  # Investigates a test file, or every test file under a folder, and prints the report.
  # Returns the exit code: 0 when nothing was found, 1 when something was, 2 when tests could not run
  class Check
    PATTERN = "**/*_{test,spec}.rb"
    # Folders of installed gems and packages, whose tests are not the project's
    SKIPPED = %w[vendor node_modules].freeze

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
      files = test_files(path)
      raise Error, "no test files (*_test.rb or *_spec.rb) in #{path}" if files.empty?

      @folder = true
      codes = {}
      finished { check_each(files, codes) }
      codes.values.max
    ensure
      summarize(files.size, codes) if codes&.any?
    end

    private

    def test_files(path)
      Dir.glob(PATTERN, base: path).sort
         .reject { |file| File.dirname(file).split("/").intersect?(SKIPPED) }
         .map { |file| File.join(path, file) }.select { |file| File.file?(file) }
    end

    # Stops when the reader of the report is gone: nobody would see the rest. After an interrupt
    # the files checked so far are still reported
    def check_each(files, codes)
      files.each.with_index(1) do |file, number|
        break if @closed

        codes[file] = investigate_in_folder(file, number, files.size)
      end
    rescue Interrupt
      output { @report.finish }
      raise
    end

    def finished
      result = yield
      output { @report.finish }
      result
    end

    def investigate_in_folder(file, number, total)
      output { @report.start(file, number, total) }
      investigate(file, nil)
    rescue Error => e
      @err.puts "deflake: #{e.message}"
      output { @report.not_checked(file, e.message) }
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
      @err.puts "deflake: #{skipped(path, line)}, nothing to report" if diagnoses.empty? && not_run.empty?
      output { @report.print(diagnoses, file: path, not_run: not_run, shared: investigation.shared_names) }
      diagnoses.all?(&:clean?) && not_run.empty? ? 0 : 1
    end

    # A reader that stops early, such as head, is not an error of deflake's. The output is flushed
    # here: otherwise the next fork flushes it and fails there
    def output
      yield
      @report.flush
    rescue Errno::EPIPE
      @closed = true
      nil
    end

    def skipped(path, line)
      return "the test at line #{line} skipped itself in every run" if line

      @folder ? "every test of #{path} skipped itself" : "every test skipped itself"
    end

    def summarize(total, codes)
      files = codes.keys.group_by { |file| codes[file] }
      checked = codes.size == total ? total : "#{codes.size} of #{total}"
      @err.puts "deflake: checked #{checked} files#{", nothing found" if files.keys == [0]}"
      { 1 => "failing or leaking tests in:", 2 => "could not check:" }.each do |code, title|
        @err.puts(title, *files[code].map { |file| "  #{file}" }) if files[code]
      end
    end
  end
end
