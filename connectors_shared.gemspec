require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'connectors_shared'
  s.version     = VERSION
  s.homepage    = 'https://github.com/elastic/connectors'
  s.metadata    = {
    'revision' => REVISION
  }
  s.summary     = 'Connectors Gem containing shared implementation of apis used by Enterprise Search'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = Dir.glob("lib/**/*", File::FNM_DOTMATCH) + [
    'LICENSE'
  ]
  s.license       = 'Elastic-2.0'

  # TODO: figure out how to pin versions without harming ent-search repo
  s.add_dependency 'activesupport'
  s.add_dependency 'bson'
end
