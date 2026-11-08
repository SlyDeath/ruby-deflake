# frozen_string_literal: true

require "minitest/autorun"

# A client that connects on first use, as $redis does: what it keeps inside is not a leak
class Client
  def initialize
    @lock = Mutex.new
  end

  def get
    @lock.synchronize { @connection ||= Object.new }
  end
end

$client = Client.new
$settings = { on_error: proc {}, model: String }

class LazyGlobalTest < Minitest::Test
  def test_one
    $client.get
    $settings[:model]
  end

  def test_two
    $client.get
  end
end
