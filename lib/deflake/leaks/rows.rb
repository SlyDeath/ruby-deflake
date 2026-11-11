# frozen_string_literal: true

module Deflake
  module Leaks
    # Database rows created or deleted outside a rolled back transaction, in every connected database
    class Rows
      INTERNAL_TABLES = %w[schema_migrations ar_internal_metadata].freeze
      MAIN = "ActiveRecord::Base"

      # Row counts per model class that owns a connection, then per table
      # ({ "ActiveRecord::Base" => { "users" => 2 } }), and how many times fixtures were loaded so far
      State = Struct.new(:counts, :loads)

      # The first test of a process loads fixtures in its setup, and those rows
      # are not its leak, so the counts right after the load are its baseline.
      # The tables a load wrote to are those of its fixture sets and any other
      # whose count it changed, such as the join table of has_and_belongs_to_many.
      # A load inside a transaction the test opened, which rolls back, is no baseline. One inside
      # a transaction that was open before the test, as test-prof's before_all opens, is
      module FixtureLoad
        def create_fixtures(...)
          before = Leaks.quietly { Rows.new.snapshot&.counts }
          super.tap do |sets|
            Leaks.quietly do
              after = Rows.new.snapshot&.counts
              tables = Rows.in_new_transaction? ? [] : Array(sets).map(&:table_name) | Rows.changed(before, after)
              Rows.fixtures_loaded(after, tables)
            end
          end
        end
      end

      class << self
        attr_reader :loads
        # Transactions open at the last snapshot, before a test
        attr_accessor :depth

        # tables: the tables this load wrote to, nil when not known
        def fixtures_loaded(counts, tables = nil)
          @loads = loads.to_i + 1
          fixture_loads[@loads] = [counts, tables]
        end

        # Load number => [the counts right after it, the tables it wrote to]
        def fixture_loads
          @fixture_loads ||= {}
        end

        # The counts right after the last load
        def after_fixtures = fixture_loads[loads]&.first

        # Tables whose row count differs between two snapshots
        def changed(before, after)
          after.to_h.flat_map do |owner, tables|
            tables.reject { |table, count| before&.dig(owner, table) == count }.keys
          end
        end

        def in_new_transaction?(open = open_transactions) = open > depth.to_i

        def open_transactions = ::ActiveRecord::Base.connection_pool.with_connection(&:open_transactions)
      end

      def snapshot
        return unless defined?(::ActiveRecord) && Leaks.loaded?(::ActiveRecord, :Base)

        watch_fixtures
        pools = connected_pools
        return if pools.empty?

        Leaks.quietly { Databases.record(pools.map(&:last)) }
        Rows.depth = Rows.open_transactions
        State.new(pools.to_h { |owner, pool| [owner, count(pool)] }, Rows.loads.to_i)
      end

      # Only databases connected before the test are compared: the rows of one
      # the test connected to first were there before it
      def diff(before, after)
        baselines = baselines(before, after)
        changes = before.counts.flat_map do |owner, tables|
          changes(owner, tables, after.counts.fetch(owner, {}), baselines[owner])
        end
        changes.sort.map { |table, change| message(table, change) }
      end

      private

      # Owner => { table => rows right after the last load during the test that wrote to it }.
      # A load whose tables are not known wrote to every table
      def baselines(before, after)
        ((before.loads + 1)..after.loads).each_with_object(Hash.new { |hash, owner| hash[owner] = {} }) do |load, all|
          counts, tables = Rows.fixture_loads[load]
          counts.to_h.each do |owner, rows|
            all[owner].merge!(tables ? rows.slice(*tables) : rows)
          end
        end
      end

      # fixtures: rows in each table the fixtures were loaded into, right after the load
      def changes(owner, before, after, fixtures)
        after.filter_map do |table, now|
          change = change(now, before.fetch(table, 0), fixtures&.fetch(table, nil))
          [name(owner, table), change] if change
        end
      end

      # Loading fixtures replaces whatever a fixture table held, so the change is counted from
      # the load. A test without a transaction that empties the table in teardown, as such tests
      # do with the fixtures they loaded, leaves nothing behind
      def change(now, before, loaded)
        change = now - (loaded || before)
        change unless change.zero? || (loaded && now.zero?)
      end

      # Tables of the main database go by their names, others get the model class in front: "AnimalsRecord.dogs"
      def name(owner, table)
        owner == MAIN ? table : "#{owner}.#{table}"
      end

      def message(table, change)
        rows = "#{change.abs} #{change.abs == 1 ? "row" : "rows"}"
        change.positive? ? "#{table}: #{rows} left behind" : "#{table}: #{rows} deleted for good"
      end

      # Model class that owns the connection ("ActiveRecord::Base", "AnimalsRecord") => its pool.
      # Shards other than the default one go by their name too: "ShardRecord[one]"
      def connected_pools
        handler = ::ActiveRecord::Base.connection_handler
        writing = ::ActiveRecord.respond_to?(:writing_role) ? ::ActiveRecord.writing_role : :writing
        shards = handler.connection_pool_list(writing).map(&:shard).uniq
        handler.connection_pool_names.product(shards).filter_map do |owner, shard|
          pool = handler.retrieve_connection_pool(owner, role: writing, shard: shard)
          [shard == ::ActiveRecord::Base.default_shard ? owner : "#{owner}[#{shard}]", pool] if pool&.connected?
        end
      end

      # Outside the query cache: a count the test makes itself, such as User.count, must still go to
      # the database, and must not find the cache emptied by deflake either. Named SCHEMA, as Rails'
      # own internal queries are, so that assert_no_queries and the log leave the counts out
      def count(pool)
        pool.with_connection do |connection|
          uncached(connection) do
            (connection.tables - INTERNAL_TABLES).to_h do |table|
              sql = "SELECT COUNT(*) FROM #{connection.quote_table_name(table)}"
              [table, connection.select_value(sql, "SCHEMA").to_i]
            end
          end
        end
      end

      def uncached(connection, &)
        return yield unless connection.respond_to?(:uncached)

        # Rails 7.2 and newer would let the counts empty the cache of other connections
        dirties = connection.method(:uncached).parameters.any? { |_, name| name == :dirties }
        dirties ? connection.uncached(dirties: false, &) : connection.uncached(&)
      end

      # Before fixtures load for the first time, without loading them: Rails tells when they do
      def watch_fixtures
        if Leaks.loaded?(::ActiveRecord, :FixtureSet)
          prepend_to(::ActiveRecord::FixtureSet)
        elsif !@waiting && defined?(::ActiveSupport.on_load)
          @waiting = true
          ::ActiveSupport.on_load(:active_record_fixture_set) { Deflake::Leaks::Rows.new.send(:prepend_to, self) }
        end
      end

      def prepend_to(fixture_set)
        fixture_set.singleton_class.prepend(FixtureLoad) unless fixture_set.singleton_class.include?(FixtureLoad)
      end
    end
  end
end
