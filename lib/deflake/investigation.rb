# frozen_string_literal: true

module Deflake
  # Runs a test file many times, then reruns every failing test on its own
  # to tell a flaky test from one broken by its neighbours, and bisects the latter
  class Investigation
    # How many failing seeds bisect tries before it gives up
    SEEDS = 3

    # line: look only at the test on this line, but still run the whole file
    def initialize(path, runs:, line: nil, jobs: 1, adapter: Adapters.for(path))
      @path = path
      @runs = runs
      @line = line
      @jobs = jobs
      @adapter = adapter
      @names = {}
    end

    # Ids of the tests on the line that never started in any run, as when an earlier test
    # always takes the process down
    attr_reader :not_run

    # Returns an array of Diagnosis, sorted by test name. It is empty when every test skipped itself.
    # With a line, errors outside of tests still show up: they may be why the test never ran
    def call
      # Before the runs, so a line without a test is reported right away
      focus = @line && @adapter.focus(@path, @line)
      summaries = focused(focus)
      summaries.values.sort_by { |summary| [summary.name, summary.id] }.map { |summary| diagnose(summary) }
    end

    # Databases that the test processes running at once shared in the runs of the whole file
    attr_reader :shared_databases

    # Names that more than one test of the file has, so a report tells them apart by their ids
    def shared_names
      @names.values.tally.select { |_, count| count > 1 }.keys
    end

    private

    # Summaries of the whole file, only of the tests in focus and errors outside of tests when there is one
    def focused(focus)
      file = runner
      summaries = file.call
      @shared_databases = file.shared_databases
      # Of every test that ran, including those that skipped themselves
      @names = file.names
      @not_run = focus ? focus - file.seen : []
      return summaries unless focus

      summaries.select { |id, _| focus.include?(id) || id == Execution::OUTSIDE }
    end

    def runner(only: nil)
      Runner.new(@path, runs: @runs, only: only, jobs: @jobs, adapter: @adapter)
    end

    def diagnose(summary)
      diagnosis = Diagnosis.new(name: summary.name, id: summary.id, file_runs: summary, isolated_runs: nil,
                                culprits: nil)
      # Errors outside of tests cannot run on their own
      return diagnosis if summary.failures.zero? || summary.id == Execution::OUTSIDE

      diagnosis = diagnosis.with(isolated_runs: isolated(summary))
      seeds = bisect_seeds(diagnosis)
      seeds.empty? ? diagnosis : diagnosis.with(culprits: bisect(summary, seeds))
    end

    # Failing seeds worth a bisect. A test that fails on its own may also fail after other tests,
    # with an error it never had alone: its seeds are bisected too
    def bisect_seeds(diagnosis)
      errors = diagnosis.file_runs.errors
      case diagnosis.verdict
      when :order_dependent then seeds_of(errors)
      when :fails_on_its_own then seeds_of(new_errors(errors, diagnosis.isolated_runs.errors))
      else []
      end
    end

    # Numbers left out: a test that fails at random tells other values every time. Bisecting it would
    # name whatever test draws random numbers before it, as Minitest seeds them once for the whole run
    def new_errors(errors, alone)
      known = alone.keys.map { |message| shape(message) }
      errors.reject { |message, _| known.include?(shape(message)) }
    end

    def shape(message)
      message.to_s.gsub(/0x\h+|\d+(?:\.\d+)?/, "N")
    end

    # The first seed of every error first, as a single odd failure may be the first one
    def seeds_of(errors)
      firsts = errors.values.map(&:first)
      (firsts + errors.values.flatten).uniq.first(SEEDS)
    end

    # When no run alone reached the test, nil: the test failed, and whether it fails on its own
    # is not known. A test that skipped itself every time it ran alone, and fails only after
    # other tests, is order dependent
    def isolated(summary)
      alone = runner(only: summary.id)
      alone.call
      alone.all[summary.id]
    rescue Execution::NoResults
      nil
    end

    # Tries the seeds one by one until bisect finds culprits, or finds the test failing alone
    def bisect(summary, seeds)
      culprits = nil
      seeds.each do |seed|
        culprits = @adapter.bisect(@path, summary.id, seed: seed)
        break if culprits.found? || culprits.alone
      end
      culprits.with(names: culprits.ids.map { |id| label(id, culprits.group_wide.include?(id)) })
    end

    # Tests with the same name are told apart by their ids
    def label(id, group_wide)
      name = @names.fetch(id, id)
      name = "#{name} (#{id})" if @names.count { |_, other| other == name } > 1
      group_wide ? "#{name} or any other test of its group (a hook of the group?)" : name
    end
  end
end
