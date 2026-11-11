# frozen_string_literal: true

require "rspec/core"
require_relative "rspec_formatter"
require_relative "leaks"

if Gem::Version.new(RSpec::Core::Version::STRING) < Gem::Version.new("3.3")
  abort "deflake needs RSpec 3.3 or newer, this is #{RSpec::Core::Version::STRING}"
end

module Deflake
  # What deflake changes in RSpec inside a test process it started
  module RSpecRun
    # deflake runs every example: a run stopped at the first failure would hide the others,
    # whether the project asks for it in .rspec or in spec_helper.rb. Nor is the profile printed,
    # which would fill the end of the output where errors outside of examples are looked for
    module Settings
      # rubocop:disable Naming/PredicateMethod -- RSpec's own names
      def fail_fast = false
      def profile_examples = false
      def profile_examples? = false
      # rubocop:enable Naming/PredicateMethod
    end

    # Errors outside of examples, such as in an after(:context) hook, go to deflake's results
    # whatever the formatters print around them
    module Reporter
      def notify_non_example_exception(exception, context_description)
        RSpecFormatter.outside(context_description, exception)
        super
      end
    end

    module_function

    # The examples deflake asked for through a file, which holds more of them than a command line could.
    # RSpec filters by ids only the files it has ids for, so the examples of a file brought in with
    # require_relative would all run: the others are excluded by their ids too. An example's :id is
    # not in its metadata until asked for, so the filter builds it from the parts RSpec builds it from
    def only(config, path)
      wanted = ResultFile.unpack_ids(File.read(path))
      wanted.group_by { |id| id[/\A(.+)\[[^\]]+\]\z/, 1] }.each do |file, ids|
        config.filter_manager.add_ids(file, ids.map { |id| id[/\[([^\]]+)\]\z/, 1] }) if file
      end
      exclude_others(config, wanted.to_set)
    end

    def exclude_others(config, wanted)
      config.filter_run_excluding(rerun_file_path: ->(file, meta) { !wanted.include?("#{file}[#{meta[:scoped_id]}]") })
    end

    # The leaks of a top-level group that none of its examples left: the state a before(:context)
    # hook sets up and does not put back
    def around_group(group, before)
      return unless before

      snapshot, reported = before
      leaks = Leaks.own(Leaks.since(snapshot), RSpecFormatter.reported.drop(reported))
      RSpecFormatter.group_leaks(group.description, leaks) if leaks.any?
    end

    def top_level?(group)
      group.superclass.equal?(RSpec::Core::ExampleGroup)
    end
  end
end

RSpec.configure do |config|
  if (path = ENV.delete(Deflake::ResultFile::ENV_KEY))
    # Here, not with --format: formatters given in SPEC_OPTS replace those on the command line
    Deflake::RSpecFormatter.path = path
    config.add_formatter(Deflake::RSpecFormatter)
    config.singleton_class.prepend(Deflake::RSpecRun::Settings)
    RSpec::Core::Reporter.prepend(Deflake::RSpecRun::Reporter)
    order = ENV.delete(Deflake::ResultFile::ORDER_KEY)
    Deflake::RSpecRun.only(config, order) if order

    config.prepend_before(:context) do
      if Deflake::RSpecRun.top_level?(self.class)
        self.class.metadata[:deflake_group] = [Deflake::Leaks.snapshot, Deflake::RSpecFormatter.reported.size]
      end
    end
    config.append_after(:context) do
      Deflake::RSpecRun.around_group(self.class, self.class.metadata.delete(:deflake_group))
    end
  end

  # Declared before the project's own hooks, so it wraps them all and a rolled
  # back transaction or a travel_back in an after hook is not reported as a leak
  config.around do |example|
    before = Deflake::Leaks.snapshot
    begin
      example.run
    ensure
      # Also when a hook inside fails after the example ran
      example.metadata[:deflake_leaks] = Deflake::Leaks.since(before)
    end
  end
end
