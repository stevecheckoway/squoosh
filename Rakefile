# frozen_string_literal: true

require 'rake/clean'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'rubygems/package_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
YARD::Rake::YardocTask.new

Gem::PackageTask.new(Gem::Specification.load('squoosh.gemspec')) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
end

task default: :spec
task gem: :spec

CLEAN.include(FileList.new('pkg', 'doc', 'coverage', '.yardoc'))
CLEAN.existing!

# vim: set sw=2 sts=2 ts=8 et:
