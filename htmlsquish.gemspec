# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'htmlsquish/version'

Gem::Specification.new do |spec|
  spec.name          = "htmlsquish"
  spec.version       = HTMLSquish::VERSION
  spec.authors       = ["Stephen Checkoway"]
  spec.email         = ["s@pahtak.org"]

  spec.summary       = "Minify HTML/CSS/JavaScript files."
  spec.homepage      = "https://github.com/stevecheckoway/htmlsquish"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.12.0"
  spec.add_runtime_dependency "uglifier", "~> 3.0"
  spec.add_runtime_dependency "sass", "~> 3.4"
  spec.add_runtime_dependency "nokogumbo", "~> 1.4", ">= 1.4.9"
end
