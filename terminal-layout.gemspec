# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'terminal_layout/version'

Gem::Specification.new do |spec|
  spec.name          = "terminal-layout"
  spec.version       = TerminalLayout::VERSION
  spec.authors       = ["Zach Dennis"]
  spec.email         = ["zach.dennis@gmail.com"]
  spec.summary       = %q{A terminal layout manager}
  spec.description   = %q{A terminal layout manager}
  spec.homepage      = "https://github.com/zdennis/terminal-layout"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  # spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby-terminfo", "~> 0.1.1"
  spec.add_dependency "ruby-termios", "~> 0.9.6"
  spec.add_dependency 'highline', '~> 1.7', '>= 1.7.8'

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2"
end
