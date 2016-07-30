$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'htmlsquish'

RSpec.configure do |config|
  config.color = true
  config.add_formatter 'documentation'
end

# vim: set sw=2 sts=2 ts=4 expandtab:
