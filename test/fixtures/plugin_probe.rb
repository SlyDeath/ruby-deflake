# frozen_string_literal: true

require "minitest/autorun"

# Passes only when Minitest loaded the plugin in plugins/, which RUBYLIB points at
class PluginProbeTest < Minitest::Test
  def test_plugin_was_loaded
    assert $deflake_probe_loaded, "the plugin was not loaded"
  end
end
