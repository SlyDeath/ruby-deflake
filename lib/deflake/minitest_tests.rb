# frozen_string_literal: true

require "minitest"
require_relative "result_file"

module Deflake
  # The tests of a Minitest process: which of them to run, in which order, and where each is declared.
  # A test is known by "Class#test_name", the class by its name, and a second class
  # with the same name, as two describe blocks with one description give, by "Class (2)"
  module MinitestTests
    # Checks what a whole class leaves behind, beyond the leaks of its tests: the state a
    # class-level hook such as minitest-hooks' before_all sets up and does not put back
    module ClassLeaks
      define_method(Minitest::VERSION.to_i < 6 ? :run : :run_suite) do |reporter, options = {}|
        recorder = MinitestReporter.current
        # Tests that run in parallel would mix their leaks with those of other classes
        order = respond_to?(:run_order) ? run_order : test_order
        return super(reporter, options) unless recorder && order != :parallel

        recorder.around_class(self) { super(reporter, options) }
      end
    end

    class << self
      # Test ids asked for through DEFLAKE_ORDER or DEFLAKE_ONLY, in the order to run them.
      # The variables are removed, so a test that starts deflake itself does not pass them on
      def requested
        order = ENV.delete(ResultFile::ORDER_KEY)
        only = ENV.delete(ResultFile::ONLY_KEY)
        return ResultFile.unpack_ids(File.read(order)) if order

        ResultFile.unpack_ids(only) if only
      end

      # Makes Minitest run exactly these tests in exactly this order. Minitest runs all tests of
      # a class together, so the ids of a recorded order come class by class. Each class still
      # seeds the random numbers as Minitest does, so code that uses rand behaves as in a whole run
      def run_only(ids)
        order = by_class(ids)
        order.each do |klass, methods|
          original = klass.method(:runnable_methods)
          klass.define_singleton_method(:runnable_methods) do
            original.call
            methods
          end
        end
        only_these(order.keys)
      end

      # Only Minitest's own run gets these classes: afterwards the tests see every class again,
      # as tests of a Minitest extension that reset and list them do
      def only_these(suites)
        # Minitest shuffles the classes before it runs them
        suites.define_singleton_method(:shuffle) { |*| self }
        OnlyThese.suites = suites
        Minitest::Runnable.singleton_class.prepend(OnlyThese)
      end

      # Gives the classes to run once, then Minitest's own list again
      module OnlyThese
        class << self
          attr_accessor :suites
        end

        def runnables
          suites = OnlyThese.suites
          return super unless suites

          OnlyThese.suites = nil
          suites
        end
      end

      # Class => its methods among these ids, in their order
      def by_class(ids)
        tests = {}
        each_test { |klass, method_name, id| tests[id] = [klass, method_name] }
        ids.filter_map { |id| tests[id] }.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
      end

      # Remembers where in this file each test is declared, before the file loads. A test that a
      # macro or Rails' test "..." defines has its method's source elsewhere
      def watch_declarations(path)
        Minitest::Runnable.singleton_class.prepend(declarations_hook(path, declared))
      end

      def declarations_hook(path, found)
        target = File.expand_path(path).b
        Module.new do
          define_method(:method_added) do |name|
            place = name.to_s.start_with?("test_") && MinitestTests.declared_at(caller_locations, target)
            found[self][name.to_s] = [path, place.lineno] if place
            super(name)
          end
        end
      end

      # The line of this file that declares the test: in the body of a class or a describe block,
      # not inside a helper method that defines tests, such as Rails' test. None for a test in
      # another file this one requires: the line of the require does not declare it
      def declared_at(locations, target)
        first = locations.index { |location| in_file?(location, target) } or return
        return if locations.first(first).any? { |location| location.label.to_s.include?("<top (required)>") }

        here = locations.select { |location| in_file?(location, target) }
        here.find { |location| location.label.to_s.include?("<") } || here.first
      end

      def in_file?(location, target)
        file = location.absolute_path || location.path
        file && File.expand_path(file).b == target
      end

      # Class => { test method => [file, line] }
      def declared
        @declared ||= Hash.new { |hash, klass| hash[klass] = {} }.compare_by_identity
      end

      # Writes every test with the file and line it is declared at, without running any.
      # A test in a class without a name has no id
      def list(path)
        Minitest::Runnable.runnables.each do |klass|
          prefix = prefix(klass)
          klass.runnable_methods.each do |method_name|
            file, line = declared[klass][method_name] || klass.instance_method(method_name).source_location
            ResultFile.append(path, listed: prefix && "#{prefix}##{method_name}", file: file, line: line)
          end
        end
      end

      def each_test
        Minitest::Runnable.runnables.each do |klass|
          prefix = prefix(klass) or next
          klass.runnable_methods.each { |method_name| yield klass, method_name, "#{prefix}##{method_name}" }
        end
      end

      # "Class", "Class (2)" for the second class with that name, nil for a class without a name
      def prefix(klass)
        prefixes[klass]
      end

      # Classes with this name, in the order they were defined
      def named(name)
        prefixes.keys.select { |klass| klass.name == name }
      end

      private

      def prefixes
        @prefixes ||= begin
          seen = Hash.new(0)
          Minitest::Runnable.runnables.select(&:name).to_h do |klass|
            count = seen[klass.name] += 1
            [klass, count == 1 ? klass.name : "#{klass.name} (#{count})"]
          end.compare_by_identity
        end
      end
    end
  end
end
