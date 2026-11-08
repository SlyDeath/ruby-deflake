# frozen_string_literal: true

require "shellwords"
require "tmpdir"

module Deflake
  module Adapters
    # Runs an RSpec file, optionally only some examples (by their ids, "./spec/foo_spec.rb[1:2]")
    module RSpec
      # Like the rspec executable: invoke turns off rspec/autorun, which would run everything twice
      RUN = "RSpec::Core::Runner.invoke"
      # Options in SPEC_OPTS that would take over what deflake sets: the seed and order of a run,
      # where the output goes and when the run stops. They win over the command line
      OWN = %w[--seed --order --rand --random --format -f --out -o --fail-fast --no-fail-fast --bisect --profile -p
               --no-profile --dry-run].freeze
      # Those of them that take a separate value
      VALUED = %w[--seed --order --format -f --out -o].freeze

      module_function

      # only: an example id, a "path:line", or a list of example ids. The profile would fill the
      # end of the output, where errors outside of examples are looked for
      def command(path, seed:, only: nil)
        # deflake/rspec adds deflake's own formatter
        [*rspec(only || path, seed), "--format", "progress", "--no-profile"]
      end

      def env(_only)
        options = ENV.fetch("SPEC_OPTS", nil)
        options ? { "SPEC_OPTS" => Shellwords.join(project_options(Shellwords.split(options))) } : {}
      end

      # SPEC_OPTS without the options deflake sets itself
      def project_options(words)
        values = 0
        words.reject do |word|
          next (values -= 1) >= 0 if values.positive?

          # "--seed 5" takes the next word too, "--seed=5" does not
          values = VALUED.include?(word) ? 1 : 0
          OWN.include?(word.split("=", 2).first)
        end
      end

      # Lets RSpec itself say which examples are at this line, as rspec path:line does: on the line
      # of a group, all its examples. A dry run lists them without running any example or hook,
      # so nothing a run does, such as --fail-fast or a hook that exits, can hide some of them.
      # Returns their ids
      def focus(path, line)
        ids = Execution.retrying { examples_at(path, line) }
        raise Error, "no test found at #{path}:#{line}" if ids.empty?

        ids
      end

      def examples_at(path, line)
        Execution.call(self, path, seed: 0, only: ["--dry-run", "#{path}:#{line}"]).map { |row| row["id"] }.uniq
      rescue Execution::NoResults => e
        # A project with fail_if_no_examples fails a run that found none
        raise unless e.success? || e.output.match?(/^0 examples, 0 failures/)

        []
      end

      # RSpec orders examples by a hash of the seed and each id, so a subset of examples runs in the
      # same relative order as in the whole file. The ids go through a file: a command line cannot
      # hold the ids of a file with thousands of examples
      def run_in_order(path, ids, seed:)
        Dir.mktmpdir do |dir|
          order = File.join(dir, "order")
          File.write(order, ResultFile.pack_ids(ids))
          Execution.call(self, path, seed: seed, env: { ResultFile::ORDER_KEY => order })
        end
      end

      # The same bisect as for Minitest, which checks only this victim. rspec --bisect
      # keeps every example that fails with the seed, and hangs when one exits the process
      def bisect(path, victim, seed:)
        bisect = Bisect.new(path, seed: seed, adapter: self)
        ids = bisect.call(victim)
        targets = if ids.any? then compact(ids + [victim])
                  elsif bisect.alone? then [victim]
                  else [path]
                  end
        Culprits.new(ids: ids, command: "rspec #{Shellwords.join(targets)} --seed #{seed}",
                     alone: bisect.alone?, hidden: bisect.hidden?, group_wide: bisect.group_wide)
      end

      # The group an example is in: "./a_spec.rb[1:2:3]" => "./a_spec.rb[1:2]"
      def group(id)
        file, scope = id.match(/\A(.+)\[([^\]]+):\d+\]\z/)&.captures
        "#{file}[#{scope}]" if file
      end

      # ["./a_spec.rb[1:1]", "./a_spec.rb[1:3]"] => ["./a_spec.rb[1:1,1:3]"], as rspec --bisect prints them
      def compact(ids)
        ids.group_by { |id| id[/\A(.+)\[[^\]]+\]\z/, 1] }.flat_map do |file, group|
          file ? "#{file}[#{group.map { |id| id[/\[([^\]]+)\]\z/, 1] }.join(",")}]" : group
        end
      end

      def rspec(target, seed)
        [RbConfig.ruby, "-I", LIB, "-r", "deflake/rspec", "-e", RUN, "--", *Array(target), "--seed", seed.to_s]
      end
    end
  end
end
