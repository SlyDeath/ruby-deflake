# frozen_string_literal: true

# A gem's Minitest plugin, for plugin_probe.rb
module Minitest
  def self.plugin_deflake_probe_init(_options)
    $deflake_probe_loaded = true
  end
end
