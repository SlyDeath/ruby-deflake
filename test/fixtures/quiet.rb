# frozen_string_literal: true

require "minitest/autorun"
require "English"

# None of these tests leaves global state behind
class QuietTest < Minitest::Test
  def test_reads_an_unset_global
    assert_nil $deflake_never_set
  end

  def test_shells_out
    assert system("true")
  end

  def test_reads_a_file
    refute_empty File.readlines(__FILE__)
  end
end
