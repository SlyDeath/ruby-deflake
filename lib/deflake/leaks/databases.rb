# frozen_string_literal: true

module Deflake
  module Leaks
    # When several test processes run at once, each tells deflake which databases it uses, so that
    # deflake can say when two of them share one: their rows would get in each other's way
    module Databases
      module_function

      def record(pools)
        folder = ENV.fetch(ResultFile::DATABASES_KEY, nil)
        return unless folder

        names = pools.filter_map { |pool| name(pool) } - recorded
        return if names.empty?

        recorded.concat(names)
        File.open(File.join(folder, "worker#{ENV.fetch("TEST_ENV_NUMBER", "")}"), "a") { |file| file.puts(names) }
      end

      def recorded
        @recorded ||= []
      end

      # A database in memory belongs to its process alone
      def name(pool)
        config = config(pool)
        database = config[:database].to_s
        return if database.empty? || database.include?(":memory:") || database.include?("mode=memory")

        database = File.expand_path(database) if config[:adapter].to_s.include?("sqlite")
        [config[:adapter], config[:host], config[:port], database].compact.join(" ")
      end

      # Rails before 6.1 has no db_config
      def config(pool)
        pool.respond_to?(:db_config) ? pool.db_config.configuration_hash : pool.spec.config
      end
    end
  end
end
