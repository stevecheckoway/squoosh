# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'squoosh'

RSpec.configure do |config|
  config.color = true
  config.add_formatter 'documentation'
end

# vim: set sw=2 sts=2 ts=4 expandtab:
