# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'connectors_service'
  s.version     = `cat VERSION`
  s.homepage    = 'https://github.com/elastic/connectors-ruby'
  s.summary     = 'Gem containing Elastic connectors service'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.executables << 'connectors_service'
  s.executables << 'native_connectors'
  s.files       = Dir['lib/**/*'] + %w[config/connectors.yml LICENSE NOTICE.txt]
  s.license     = 'Elastic-2.0'
end
