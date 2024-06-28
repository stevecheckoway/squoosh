# frozen_string_literal: true

require "minitest/test_task"
require "rake/clean"
require "rubocop/rake_task"
require "rubygems/package_task"
require "yard"

Minitest::TestTask.create
RuboCop::RakeTask.new
YARD::Rake::YardocTask.new

Gem::PackageTask.new(Gem::Specification.load("squoosh.gemspec")) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
end

task default: [:rubocop, :test]
task gem: [:test]

CLEAN.include(FileList.new("pkg", "doc", "coverage", ".yardoc"))
CLEAN.existing!

# vim: set sw=2 sts=2 ts=8 et:
