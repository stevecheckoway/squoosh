# frozen_string_literal: true

require "minitest/autorun"
require "minitest/reporters"
require "minitest/proveit"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
Minitest::Test.prove_it! # Force tests to prove success via assertions

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "squoosh"

# vim: set sw=2 sts=2 ts=4 expandtab:
