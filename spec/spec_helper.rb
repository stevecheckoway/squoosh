# frozen_string_literal: true

require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = 'coverage/lcov.info'
end
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
)

SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'squoosh'

RSpec.configure do |config|
  config.color = true
  config.add_formatter :documentation
end

# vim: set sw=2 sts=2 ts=4 expandtab:
