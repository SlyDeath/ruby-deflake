# frozen_string_literal: true

module Deflake
  # The end of a test process's output, where test frameworks say what went wrong, cleaned of
  # what changes from run to run, so one error stays one error
  module Tail
    # How many lines an error shows
    LINES = 15
    # How much of the end of the output is read: a log of hundreds of megabytes stays on disk
    KEEP = 256 * 1024
    # Whole lines the test frameworks print that change from run to run (the seed, the timing,
    # the counts, the progress dots)
    NOISE = Regexp.union(/\A(?:Run options:|Randomized with seed \d+\z|Finished in |# Running:\z|[.FESP*]+\z)/,
                         /\A\d+ runs?, \d+ assertions?/, /\A\d+ examples?, \d+ failures?/)
    # Progress dots stuck to the start of a line the tests printed, but not those of "./path"
    PROGRESS = %r{\A[.FESP*]*\.(?![./])}
    # A seed inside a line, such as "Started with run options --seed 41234"
    SEED = /\b(seed[ =:]+)\d+/i
    # Frames of a backtrace, which Ruby prints after the message
    FRAME = /\A\s+from /
    # Frames kept of each backtrace
    FRAMES = 3

    module_function

    # The message, and the end of the output when there is one. Long backtraces are cut short,
    # so the message before them stays in
    def with(message, output)
      tail = lines(output)
      tail.empty? ? message : "#{message}, its output ended with:\n#{tail.join("\n")}"
    end

    def read(log)
      File.open(log, "rb") do |file|
        cut = file.size > KEEP
        file.seek(-KEEP, IO::SEEK_END) if cut
        text = file.read
        cut ? text.sub(/\A[^\n]*\n/, "") : text
      end
    end

    def lines(output)
      lines = without_pending(output.lines.map(&:rstrip)).map { |line| line.sub(PROGRESS, "").gsub(SEED, '\1N') }
      short_frames(lines.reject { |line| line.empty? || line.strip.match?(NOISE) }).last(LINES)
    end

    # RSpec lists pending examples in the order they ran, which changes with the seed
    def without_pending(lines)
      skipping = false
      lines.reject do |line|
        skipping = true if line.start_with?("Pending:")
        skipping = false if skipping && !line.empty? && !line.start_with?(" ", "Pending:")
        skipping
      end
    end

    def short_frames(lines)
      run = 0
      lines.filter_map do |line|
        run = line.match?(FRAME) ? run + 1 : 0
        next line if run <= FRAMES

        "\t ... more frames" if run == FRAMES + 1
      end
    end
  end
end
