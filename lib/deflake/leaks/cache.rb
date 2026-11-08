# frozen_string_literal: true

module Deflake
  module Leaks
    # Keys left in Rails.cache, when it is a MemoryStore
    class Cache
      # How many of the new keys a message lists
      SHOWN = 3

      def snapshot
        return unless defined?(::Rails) && ::Rails.respond_to?(:cache)
        return unless defined?(::ActiveSupport::Cache::MemoryStore)

        store = ::Rails.cache
        store.instance_variable_get(:@data).keys if store.is_a?(::ActiveSupport::Cache::MemoryStore)
      end

      def diff(before, after)
        added = after - before
        return [] if added.empty?

        # Long numbers, such as times and versions, change from run to run
        listed = added.first(SHOWN).map { |key| key.inspect.gsub(/\d{6,}/, "N") }.join(", ")
        listed += ", ..." if added.size > SHOWN
        ["Rails.cache has #{added.size} new #{added.size == 1 ? "key" : "keys"}: #{listed}"]
      end
    end
  end
end
