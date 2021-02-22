# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ingress/version'

Gem::Specification.new do |spec|
  spec.name          = "ingress"
  spec.version       = Ingress::VERSION
  spec.authors       = ["Alan Skorkin"]
  spec.email         = ["alan@skorks.com"]

  spec.summary       = %q{Simple role based authorization for Ruby applications}
  spec.homepage      = ""
  spec.license       = "MIT"
  spec.metadata      = {
                         "bug_tracker_uri" => "https://github.com/skorks/ingress/issues",
                         "source_code_uri" => "https://github.com/skorks/ingress",
                       }

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2.2", "< 3"
  spec.add_development_dependency "rake", ">= 13.0.3"
  spec.add_development_dependency "rspec"
end
