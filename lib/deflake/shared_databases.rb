# frozen_string_literal: true

require "tmpdir"

module Deflake
  # Databases that test processes running at once both used: each process writes the names
  # of its databases to a file of its own in a folder, see Leaks::Databases
  class SharedDatabases
    attr_reader :shared

    def initialize
      @shared = []
    end

    # Yields the folder, nil with one process at a time, when no database can be shared
    def watch(jobs)
      return yield nil if jobs == 1

      Dir.mktmpdir do |folder|
        result = yield folder
        @shared = shared_in(folder)
        result
      end
    end

    private

    def shared_in(folder)
      used = Dir.children(folder).map { |worker| File.readlines(File.join(folder, worker), chomp: true).uniq }
      used.flatten.tally.select { |_, workers| workers > 1 }.keys.sort
    end
  end
end
