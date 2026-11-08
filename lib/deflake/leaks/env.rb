# frozen_string_literal: true

module Deflake
  module Leaks
    # Environment variables set, changed or removed
    class Env
      def snapshot
        ENV.to_h
      end

      def diff(before, after)
        (before.keys | after.keys).sort.filter_map do |key|
          next if before[key] == after[key]

          change = if !after.key?(key) then "was removed"
                   elsif before.key?(key) then "was changed"
                   else "was set"
                   end
          "ENV[#{key.inspect}] #{change}"
        end
      end
    end
  end
end
