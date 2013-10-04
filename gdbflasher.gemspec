# -*- encoding: utf-8 -*-
require File.expand_path('../lib/gdbflasher/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Sergey Gridasov"]
  gem.email         = ["grindars@gmail.com"]
  gem.description   = %q{gdbflasher is a gdbserver-compatible tool for loading firmware into ARM MCUs.}
  gem.summary       = %q{Retargetable flasher for ARM microcontrollers}
  gem.homepage      = "https://github.com/grindars/gdbflasher"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "gdbflasher"
  gem.require_paths = ["lib"]
  gem.version       = GdbFlasher::VERSION

  gem.add_dependency 'trollop'
end
