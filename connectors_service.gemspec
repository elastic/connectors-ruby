require_relative 'lib/app/config'

Gem::Specification.new do |s|
  s.name        = 'connectors_service'
  s.version     = App::Config[:version]
  s.homepage    = 'https://github.com/elastic/connectors-ruby'
  s.summary     = 'Gem containing Elastic connectors service'
  s.description = ''
  s.authors     = ['Elastic']
  s.metadata    = {
      "revision" => App::Config[:revision],
      "repository" => App::Config[:repository]
  }
  s.email       = 'ent-search-dev@elastic.co'
  s.executables << 'connectors_service'
  s.files       = Dir['lib/**/*'] + %w[LICENSE NOTICE.txt]
  s.license     = 'Elastic-2.0'
end
