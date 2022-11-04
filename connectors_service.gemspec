# frozen_string_literal: true

require_relative 'lib/app/config'

Gem::Specification.new do |s|
  s.name        = 'connectors_service'
  s.version     = App::Config[:version]
  s.homepage    = 'https://github.com/elastic/connectors-ruby'
  s.summary     = 'Gem containing Elastic connectors service'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.executables << 'connectors_service'
  s.executables << 'list_connectors'
  s.files       = Dir['lib/**/*'] + %w[config/connectors.yml LICENSE NOTICE.txt]
  s.license     = 'Elastic-2.0'
  Bundler.definition.dependencies.select do |dep|
    (dep.groups & [:test, :development]).empty?
  end.sort_by(&:name).each do |dep|
    if dep.latest_version?
      s.add_dependency dep.name
    else
      s.add_dependency dep.name, dep.requirement
    end
  end
end
