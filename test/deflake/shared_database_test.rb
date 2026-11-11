# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"

module Deflake
  # Test processes running at once that share a database
  class SharedDatabaseTest < Minitest::Test
    def test_warns_of_one_database_shared_by_parallel_processes
      _, _, parallel = run_cli(fixture("locked.rb"), "--runs", "2", "--jobs", "2")
      _, _, serial = run_cli(fixture("locked.rb"), "--runs", "1")

      assert_includes parallel, "seem to wait for each other on one database"
      refute_includes serial, "TEST_ENV_NUMBER"
    end

    def test_names_a_database_that_parallel_processes_share
      Dir.mktmpdir do |dir|
        ENV["DEFLAKE_FIXTURE_DB"] = File.join(dir, "test.sqlite3")

        assert_includes shared_db_warning, "used the same database (sqlite3 #{File.realpath(dir)}/test.sqlite3)"
        ENV["DEFLAKE_FIXTURE_DB_PER_WORKER"] = "1"

        refute_includes shared_db_warning, "TEST_ENV_NUMBER"
      ensure
        ENV.delete("DEFLAKE_FIXTURE_DB")
        ENV.delete("DEFLAKE_FIXTURE_DB_PER_WORKER")
      end
    end

    private

    def shared_db_warning
      run_cli(fixture("rails_shared_db.rb"), "--runs", "4", "--jobs", "2").last
    end

    def fixture(name)
      File.expand_path("../fixtures/#{name}", __dir__)
    end

    def run_cli(*argv)
      out = StringIO.new
      err = StringIO.new
      status = CLI.new(argv, out: out, err: err).run
      [status, out.string, err.string]
    end
  end
end
