# frozen_string_literal: true

module Deflake
  module Leaks
    # Global variables ($name) assigned or changed in place
    class Globals
      # Ruby itself changes these all the time, including the English names of $?, $., $_ and friends
      IGNORED = %i[
        $LOADED_FEATURES $LOAD_PATH $PROGRAM_NAME $FILENAME $DEBUG $VERBOSE $stdin $_
        $ERROR_INFO $ERROR_POSITION $FS $FIELD_SEPARATOR $OFS $OUTPUT_FIELD_SEPARATOR
        $RS $INPUT_RECORD_SEPARATOR $ORS $OUTPUT_RECORD_SEPARATOR $INPUT_LINE_NUMBER $NR
        $LAST_READ_LINE $DEFAULT_OUTPUT $DEFAULT_INPUT $PID $PROCESS_ID $CHILD_STATUS
        $LAST_MATCH_INFO $IGNORECASE $ARGV $MATCH $PREMATCH $POSTMATCH $LAST_PAREN_MATCH
      ].freeze
      # How deep fingerprint walks into containers
      DEPTH = 32

      # An object Marshal could dump (digest) or not (nil), known by its identity too
      Leaf = Struct.new(:id, :digest)
      # A container, part by part, and its digest when Marshal could dump it whole. In a Hash or a
      # Set the order of the parts does not matter
      Box = Struct.new(:id, :type, :unordered, :parts, :digest)

      # Ruby creates a global as nil the first time code reads it, so nil counts as unset.
      # The value may be any object, even one without Kernel's methods, such as a mock
      def snapshot
        names = global_variables.grep(/\A\$[A-Za-z_]\w*\z/) - IGNORED
        names.filter_map do |name|
          value = TOPLEVEL_BINDING.eval(name.to_s)
          [name, safely(value)] unless NilClass === value # rubocop:disable Style/CaseEquality
        end.to_h
      end

      def diff(before, after)
        (before.keys | after.keys).sort.filter_map do |name|
          next if before.key?(name) && after.key?(name) && same?(before[name], after[name])

          before.key?(name) ? "#{name} was changed" : "#{name} was set"
        end
      end

      private

      def safely(value)
        fingerprint(value)
      rescue StandardError, ScriptError, SystemStackError
        Leaf.new(value.__id__, nil)
      end

      # The contents, so a change inside any object counts, not only inside strings, arrays and
      # hashes. Containers are walked part by part, down to DEPTH, so a proc added to an array
      # counts as a change. Any other object is dumped with Marshal, and one Marshal cannot dump
      # (a Mutex, a proc, an IO) counts by identity: what it keeps inside, such as a lazily opened
      # connection, is its own business. So does one Marshal could dump before the test and not
      # after, or the other way round: it may have set up something inside on first use
      def fingerprint(value)
        walk(value, {}.compare_by_identity, 0)
      end

      def walk(value, seen, depth)
        # Deeper parts and containers met before count by identity: walking them again would never end
        return Leaf.new(value.__id__, nil) if depth > DEPTH || seen.key?(value)

        parts = parts(value)
        return Leaf.new(value.__id__, dump_or_nil(value)) unless parts

        seen[value] = true
        box(value, parts.map { |part| walk(part, seen, depth + 1) }, depth.zero?)
      end

      # Only the whole value gets a digest: it makes comparing an unchanged value quick
      def box(value, parts, whole)
        Box.new(value.__id__, type(value), unordered?(value), parts, whole ? dump_or_nil(value) : nil)
      end

      # A Hash also by its default and by how it compares keys
      def type(value)
        return value.class unless Hash === value # rubocop:disable Style/CaseEquality

        [value.class, value.compare_by_identity?, dump_or_nil(value.default), !value.default_proc.nil?]
      end

      def dump_or_nil(value)
        Marshal.dump(value).hash
      rescue StandardError, SystemStackError
        nil
      end

      def same?(before, after)
        return before.id == after.id unless before.instance_of?(after.class)
        return leaf_same?(before, after) if before.is_a?(Leaf)
        return false unless before.type == after.type && before.parts.size == after.parts.size

        box_same?(before, after)
      end

      def leaf_same?(before, after)
        before.digest && after.digest ? before.digest == after.digest : before.id == after.id
      end

      def box_same?(before, after)
        return true if before.digest && before.digest == after.digest
        return before.parts.zip(after.parts).all? { |one, other| same?(one, other) } unless before.unordered

        same_in_any_order?(*unmatched(before.parts, after.parts))
      end

      def same_in_any_order?(left, right)
        left.all? do |part|
          index = right.index { |other| same?(part, other) }
          index && right.delete_at(index)
        end
      end

      # The parts of a Hash or a Set that have no equal part on the other side, found by their
      # digests first: comparing every part with every other would take long in a big Hash
      def unmatched(before, after)
        counts = before.map { |part| signature(part) }.tally
        right = after.reject { |part| take(counts, signature(part)) }
        [before.select { |part| take(counts, signature(part)) }, right]
      end

      # Takes one of the parts with this signature, if any is left
      def take(counts, key)
        counts[key].to_i.positive? && (counts[key] -= 1)
      end

      # Equal parts have equal signatures. An object Marshal cannot dump has its identity instead
      def signature(part)
        return part.digest || [:id, part.id].hash if part.is_a?(Leaf)

        parts = part.parts.map { |inner| signature(inner) }
        [part.type, part.unordered ? parts.sort : parts].hash
      end

      def unordered?(value)
        Hash === value || (defined?(::Set) && ::Set === value) # rubocop:disable Style/CaseEquality
      end

      # The parts of a container, nil for anything else. A Hash gives its entries, as pairs.
      # Set and StringIO may not be loaded
      def parts(value)
        case value
        when Array, Struct, Hash then value.to_a
        when Thread::Queue then [value.size, value.closed?]
        else loaded_parts(value)
        end
      end

      def loaded_parts(value)
        if defined?(::Set) && ::Set === value then value.to_a # rubocop:disable Style/CaseEquality
        elsif defined?(::StringIO) && ::StringIO === value then [value.string, value.pos] # rubocop:disable Style/CaseEquality
        end
      end
    end
  end
end
