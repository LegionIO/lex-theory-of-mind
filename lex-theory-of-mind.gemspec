# frozen_string_literal: true

require_relative 'lib/legion/extensions/theory_of_mind/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-theory-of-mind'
  spec.version       = Legion::Extensions::TheoryOfMind::VERSION
  spec.authors       = ['Matthew Iverson']
  spec.email         = ['matt@legionIO.com']
  spec.summary       = 'Theory of Mind for LegionIO cognitive agents'
  spec.description   = 'Models other agents mental states — beliefs, desires, intentions — enabling perspective-taking and behavior prediction'
  spec.homepage      = 'https://github.com/LegionIO/lex-theory-of-mind'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.add_development_dependency 'legion-gaia'
end
