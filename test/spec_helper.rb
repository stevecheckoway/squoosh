# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"
require "minitest/autorun"
require "minitest/reporters"
require "minitest/proveit"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
Minitest::Test.prove_it! # Force tests to prove success via assertions

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = "coverage/lcov.info"
end
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
)

SimpleCov.start

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "squoosh"

# vim: set sw=2 sts=2 ts=4 expandtab:
