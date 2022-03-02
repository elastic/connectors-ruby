require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'connectors_shared'
  s.version     = VERSION
  s.summary     = 'Connectors Gem containing shared implementation of apis used by Enterprise Search'
  s.description = "connectors_shared #{VERSION}"
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = Dir['lib/connectors_shared/**/*'].to_a +
                  Dir['lib/connectors/base/**/*'].to_a <<
                  'lib/connectors_shared.rb'
  s.homepage    = 'https://elastic.co'
  s.license     = 'Elastic-2.0'

  # TODO: figure out how to pin versions without harming ent-search repo
  s.add_dependency 'activesupport'
  s.add_dependency 'bson'
end
