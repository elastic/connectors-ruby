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
  s.executables << 'list_connectors'
  s.files       = Dir['lib/**/*'] + %w[config/connectors.yml LICENSE NOTICE.txt]
  s.license     = 'Elastic-2.0'
  s.add_dependency 'ecs-logging', `~> 1.0`
  s.add_dependency 'activesupport', '~>5.2.6'
  s.add_dependency 'mime-types', '= 3.1'
  s.add_dependency 'tzinfo-data'
  s.add_dependency 'tzinfo'
  s.add_dependency 'nokogiri', '>= 1.13.6', :require => false
  s.add_dependency 'fugit', '~> 1.5.3'
end
