require_relative 'lib/config'


Gem::Specification.new do |s|
  s.name        = 'connectors_shared'
  s.version     = Connectors::Config['version']
  s.homepage    = "https://github.com/elastic/connectors"
  s.summary     = 'Connectors Gem containing shared implementation of apis used by Enterprise Search'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.metadata    = {
    "revision" => Connectors::Config['revision'],
    "repository" => Connectors::Config['repository']
  }
  s.files       = Dir.glob("lib/**/*", File::FNM_DOTMATCH) + [
    'LICENSE', 'config/connectors.yml'
  ]
  s.license       = 'Elastic-2.0'

  # TODO: figure out how to pin versions without harming ent-search repo
  s.add_dependency 'activesupport'
  s.add_dependency 'bson'
end
