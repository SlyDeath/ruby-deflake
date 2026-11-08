# frozen_string_literal: true

module Deflake
  # A file where a test process records one JSON line per test: a "started" line
  # when the test begins and a result line when it ends. The test process writes it without
  # the json library, which would add methods such as Object#to_json to the tests it runs
  module ResultFile
    # Name of the environment variable that tells a test process where to write
    ENV_KEY = "DEFLAKE_OUTPUT"
    # Path of a file with test ids to run in exactly this order instead of the whole file
    ORDER_KEY = "DEFLAKE_ORDER"
    # Test ids to run, like ORDER_KEY but for a few ids passed directly (Minitest)
    ONLY_KEY = "DEFLAKE_ONLY"
    # Path of the file whose tests to list, with where each is defined, instead of running them (Minitest)
    LIST_KEY = "DEFLAKE_LIST"
    # Every variable that tells a test process what to do: a test that starts deflake itself
    # must not pass them on
    KEYS = [ENV_KEY, ORDER_KEY, ONLY_KEY, LIST_KEY].freeze
    # Characters JSON escapes with a short form; other control characters become \u00XX
    ESCAPES = { '"' => '\\"', "\\" => "\\\\", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t" }.freeze

    module_function

    def append(path, **fields)
      File.open(path, "a") { |file| file.puts(generate(clean(fields))) }
    end

    # Creates the file, so a run where no test wrote a line still tells that the process got going
    def start(path)
      File.open(path, "a", &:itself)
    end

    # A process killed in the middle of a write leaves a broken last line, which is skipped
    def read(path)
      require "json"
      File.readlines(path, mode: "r:UTF-8").filter_map do |line|
        JSON.parse(line)
      rescue JSON::ParserError
        nil
      end
    end

    # Test ids as one line of text, for an environment variable or a file
    def pack_ids(ids)
      [Marshal.dump(Array(ids).map { |id| clean(id) })].pack("m0")
    end

    def unpack_ids(text)
      Marshal.load(text.unpack1("m0")) # rubocop:disable Security/MarshalLoad
    end

    # Error messages can carry bytes that are not valid UTF-8, which JSON refuses. A string in
    # another encoding, such as Latin-1, is converted, not just relabelled
    def clean(value)
      case value
      when String then clean_string(value)
      when Array then value.map { |item| clean(item) }
      when Hash then value.to_h { |key, item| [key.to_s, clean(item)] }
      else value
      end
    end

    def clean_string(value)
      if value.valid_encoding? && ![Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII].include?(value.encoding)
        value.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      else
        String.new(value, encoding: Encoding::UTF_8).scrub
      end
    end

    # JSON of strings, numbers, true, false, nil, arrays and hashes, which is all a results line holds
    def generate(value)
      case value
      when Array then "[#{value.map { |item| generate(item) }.join(",")}]"
      when Hash then "{#{value.map { |key, item| "#{quote(key.to_s)}:#{generate(item)}" }.join(",")}}"
      when nil, true, false, Integer, Float then scalar(value)
      else quote(value.to_s)
      end
    end

    def scalar(value)
      value.nil? || (value.is_a?(Float) && !value.finite?) ? "null" : value.to_s
    end

    def quote(text)
      "\"#{text.gsub(/["\\\x00-\x1f]/) { |char| ESCAPES[char] || format("\\u%04x", char.ord) }}\""
    end
  end
end
