require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'connectors_shared'
  s.version     = VERSION
  s.summary     = 'Connectors Gem containing shared implementation of apis used by Enterprise Search'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = [
    'lib/connectors_shared.rb',
    'lib/connectors_shared/constants.rb',
    'lib/connectors_shared/errors.rb',
    'lib/connectors_shared/exception_tracking.rb',
    'lib/connectors_shared/logger.rb',
    'lib/connectors_shared/monitor.rb',
    'LICENSE'
  ]
  s.homepage    =
    'https://elastic.co'
  s.license       = 'Elastic-2.0'

  # TODO: figure out how to pin versions without harming ent-search repo
  s.add_dependency 'activesupport'
  s.add_dependency 'bson'
end
