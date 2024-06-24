# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "squoosh/version"

Gem::Specification.new do |spec|
  spec.name = "squoosh"
  spec.version = Squoosh::VERSION
  spec.authors = ["Stephen Checkoway"]
  spec.email = ["s@pahtak.org"]

  spec.summary = "Minify HTML/CSS/JavaScript files."
  spec.homepage = "https://github.com/stevecheckoway/squoosh"
  spec.license = "MIT"
  spec.files = %w[LICENSE.txt README.md] + Dir["lib/**/*.rb"]

  # rubocop:disable Layout/HashAlignment
  spec.metadata = {
    "bug_tracker_uri"       => "https://github.com/stevecheckoway/squoosh/issues",
    "changelog_uri"         => "https://github.com/stevecheckoway/squoosh/blob/master/CHANGELOG.md",
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => "https://github.com/stevecheckoway/squoosh",
    "rubygems_mfa_required" => "true"
  }
  # rubocop: enable Layout/HashAlignment

  spec.required_ruby_version = ">= 2.6", "< 4.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-lcov"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "yard"

  spec.add_runtime_dependency "nokogiri", "~> 1.12"
  spec.add_runtime_dependency "sassc", "~> 2.1"
  spec.add_runtime_dependency "uglifier", "~> 4.1"
end
# vim: set sw=2 sts=2 ts=8 et:
