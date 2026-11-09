# frozen_string_literal: true

require "optparse"

module Deflake
  # Command-line entry point
  class CLI
    REPORTS = { "text" => TextReport, "json" => JsonReport }.freeze

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
      @options = { runs: 10, jobs: 1, format: "text", timeout: nil }
    end

    # Returns the process exit code
    def run
      dispatch
    rescue OptionParser::ParseError, Error => e
      complain(e.message, usage: e.is_a?(OptionParser::ParseError))
    rescue Interrupt
      interrupted
    rescue StandardError => e
      # 1 would mean flaky tests were found, so anything unexpected is a 2 as well
      complain("unexpected error, please report it: #{e.class}: #{e.message}\n  #{e.backtrace&.first(5)&.join("\n  ")}")
    end

    private

    def dispatch
      case parse_command
      when :version then @out.puts "deflake #{VERSION}"
      when :help then @out.puts parser
      else return run_tests
      end
      0
    end

    # The test processes are stopped on the way out
    def interrupted
      @err.puts "deflake: interrupted"
      130
    end

    def complain(message, usage: false)
      @err.puts "deflake: #{message}"
      @err.puts parser if usage
      2
    end

    def parse_command
      command = nil
      define_options
      parser.on("-v", "--version", "Print version and exit") { command = :version }
      parser.on("-h", "--help", "Show this help and exit") { command = :help }
      parser.parse!(@argv)
      command || check_paths
    end

    def check_paths
      raise OptionParser::MissingArgument, "TEST_PATH" if @argv.empty? || @argv.first.empty?
      raise OptionParser::NeedlessArgument, "#{@argv.drop(1).join(" ")} (one TEST_PATH at a time)" if @argv.size > 1

      :run
    end

    def define_options
      count(:runs, "-n", "--runs N", "How many times to run the file (default: 10)")
      count(:jobs, "-j", "--jobs N", "How many test processes to run at once (default: 1)")
      count(:timeout, "-t", "--timeout SECONDS", "Stop a test process that runs longer (default: no limit)")
      parser.on("-f", "--format FORMAT", REPORTS.keys, "Report format: text or json (default: text)") do |format|
        @options[:format] = format
      end
    end

    # Decimal, not Integer: Integer reads 010 as 8
    def count(option, *switches)
      parser.on(*switches[0, 2], OptionParser::DecimalInteger, switches[2]) { |n| @options[option] = positive(n) }
    end

    def positive(number)
      raise OptionParser::InvalidArgument, "#{number} (must be 1 or more)" unless number.positive?

      number
    end

    def run_tests
      path, line = target
      Execution.timeout = @options[:timeout]
      report = REPORTS.fetch(@options[:format]).new(@out, err: @err)
      check = Check.new(report, err: @err, runs: @options[:runs], jobs: @options[:jobs])
      return check.file(path, line) if File.file?(path)
      raise Error, "no such file: #{path}" unless File.directory?(path)
      raise Error, "#{path} is a folder: a line number needs a test file" if line

      check.folder(path)
    end

    # A file or folder whose name itself ends in ":12" is that one, not line 12 of another. The path is
    # taken as UTF-8 whatever the locale, as names in the report are
    def target
      argument = ResultFile.clean(@argv.first)
      return [argument, nil] if File.exist?(argument)

      path, line = argument.match(/\A(.+?)(?::(\d+))?\z/m).captures
      [path, line&.to_i]
    end

    def parser
      @parser ||= OptionParser.new("Usage: deflake TEST_PATH[:LINE] [options]\n" \
                                   "TEST_PATH may be a folder: every *_test.rb and *_spec.rb in it is checked")
    end
  end
end
