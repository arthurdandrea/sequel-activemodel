# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sequel/activemodel/version'

Gem::Specification.new do |spec|
  spec.name          = 'sequel-activemodel'
  spec.version       = Sequel::ActiveModel::VERSION
  spec.authors       = ["Arthur D'Andréa Alemar"]
  spec.email         = ['aalemmar@gmail.com']

  spec.summary       = %q{Provides Sequel::Model plugins that expose ActiveModel::Callbacks, ActiveModel::Translation and ActiveModel::Validations features to Sequel::Model}
  spec.homepage      = 'https://github.com/arthurdandrea/sequel-activemodel'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'sequel'
  spec.add_runtime_dependency 'activemodel'
  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'sqlite3'
end
