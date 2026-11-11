# frozen_string_literal: true

require_relative "deflake/version"

module Deflake
  class Error < StandardError; end

  # deflake's own code, added with -I to every test process it starts
  LIB = __dir__
end

require_relative "deflake/run"
require_relative "deflake/summary"
require_relative "deflake/result_file"
require_relative "deflake/tail"
require_relative "deflake/child"
require_relative "deflake/execution"
require_relative "deflake/culprits"
require_relative "deflake/bisect"
require_relative "deflake/adapters"
require_relative "deflake/shared_databases"
require_relative "deflake/runner"
require_relative "deflake/diagnosis"
require_relative "deflake/investigation"
require_relative "deflake/text_report"
require_relative "deflake/json_report"
require_relative "deflake/check"
require_relative "deflake/cli"
