# frozen_string_literal: true

require "shellwords"
require "tmpdir"

module Deflake
  module Adapters
    # Runs a Minitest file, optionally only some of its tests, by ids such as "Class#test_name"
    module Minitest
      module_function

      # Which tests to run goes through env. lib and test are on the load path as with rake test,
      # and spec too when there is one, for Minitest::Spec files that require spec_helper
      def command(path, seed:, **)
        [RbConfig.ruby, "-I", LIB, *load_path.flat_map { |dir| ["-I", dir] }, "-r", "deflake/minitest", path,
         "--seed", seed.to_s]
      end

      def load_path
        %w[lib test spec].select { |dir| dir == "test" || File.directory?(dir) }
      end

      # The ids go through the environment, not --name: a regexp on the command line follows
      # the locale, and under LANG=C it never matches a name that is not ASCII
      def env(only)
        only ? { ResultFile::ONLY_KEY => ResultFile.pack_ids(only) } : {}
      end

      # Matches the tests defined closest above this line. Minitest itself says which tests there
      # are, and where in this file each one is declared, so Rails' test "...", Minitest::Spec's
      # it "..." and tests a macro defines work too. Returns their ids
      def focus(path, line)
        above = definitions(path).select { |test| test[:line] <= line }
        nearest = above.map { |test| test[:line] }.max
        raise Error, "no test found at #{path}:#{line}" unless nearest

        named = above.filter_map { |test| test[:id] if test[:line] == nearest }
        return named if named.any?

        raise Error, "the test at #{path}:#{line} is in a class without a name, which deflake cannot run alone; " \
                     "run the whole file instead"
      end

      # Tests declared in this file: { id:, line: }, with a nil id for a test in a class without a name
      def definitions(path)
        here = File.expand_path(path).b
        env = { ResultFile::LIST_KEY => ResultFile.clean(File.expand_path(path)) }
        rows = Execution.retrying { Execution.call(self, path, seed: 0, env: env) }
        rows.select { |row| row["file"] && File.expand_path(row["file"]).b == here }
            .map { |row| { id: row["listed"], line: row["line"] } }
      end

      # The order goes through a file: an environment variable cannot hold a big file's test ids
      def run_in_order(path, ids, seed:)
        Dir.mktmpdir do |dir|
          order = File.join(dir, "order")
          File.write(order, ResultFile.pack_ids(ids))
          Execution.call(self, path, seed: seed, env: { ResultFile::ORDER_KEY => order })
        end
      end

      def bisect(path, victim, seed:)
        bisect = Bisect.new(path, seed: seed, adapter: self)
        ids = bisect.call(victim)
        Culprits.new(ids: ids, command: reproduce(path, seed), alone: bisect.alone?, hidden: bisect.hidden?,
                     group_wide: bisect.group_wide)
      end

      # The class: its hooks, such as minitest-hooks' before_all, run with any of its tests
      def group(id)
        id.split("#", 2).first
      end

      # With the variables Execution sets: without them Rails' parallelize gives a seed another order
      def reproduce(path, seed)
        variables = Execution::SERIAL.map { |name, value| "#{name}=#{value}" }.join(" ")
        "#{variables} ruby #{load_path.map { |dir| "-I#{dir}" }.join(" ")} #{Shellwords.escape(path)} --seed #{seed}"
      end
    end
  end
end
