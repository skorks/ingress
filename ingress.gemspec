# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ingress/version"

Gem::Specification.new do |spec|
  spec.name          = "ingress"
  spec.version       = Ingress::VERSION
  spec.authors       = ["Alan Skorkin"]
  spec.email         = ["alan@skorks.com"]

  spec.summary       = "Simple role based authorization for Ruby applications"
  spec.homepage      = ""
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/skorks/ingress/issues",
    "source_code_uri" => "https://github.com/skorks/ingress",
    "rubygems_mfa_required" => "true"
  }

  spec.files         = Dir.glob("lib/**/*") + ["README.md", "LICENSE.txt", "CLAUDE.md"]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2.6"
  spec.add_development_dependency "rake", ">= 13.1.0"
  spec.add_development_dependency "rspec", ">= 3.12"
  spec.add_development_dependency "rubocop", ">= 1.50"
  spec.add_development_dependency "rubocop-rspec", ">= 2.20"
  spec.add_development_dependency "simplecov", ">= 0.22"
end
