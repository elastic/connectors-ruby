# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'ent-search-connectors'
  s.version     = '0.0.1' # TODO: keep version somewhere accessible from gemfile and Makefile
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
    'lib/stubs/swiftype/exception_tracking.rb',
    'lib/stubs/app_config.rb'
  ]
  s.homepage    =
    'https://elastic.co'
  s.license       = 'Nonstandard'
end
