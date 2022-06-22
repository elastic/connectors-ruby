require_relative 'lib/app/config'

Gem::Specification.new do |s|
  s.name        = 'connectors_stubs'
  s.version     = ConnectorsApp::Config['version']
  s.homepage    = "https://github.com/elastic/connectors"
  s.summary     = 'Gem containing utilities used by implementations of Connectors when run external to Enterprise Search'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.metadata    = {
    "revision" => ConnectorsApp::Config['revision'],
    "repository" => ConnectorsApp::Config['repository']
  }
  s.files       = Dir.glob("lib/stubs/**/*", File::FNM_DOTMATCH) +
    [
      'LICENSE',
      'NOTICE.txt'
    ]
  s.license     = 'Elastic-2.0'

  s.add_dependency 'activesupport'
end
