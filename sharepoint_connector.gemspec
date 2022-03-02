require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'sharepoint_connector'
  s.version     = VERSION
  s.summary     = 'Gem containing the Sharepoint Connector implementation'
  s.description = "sharepoint_connector #{VERSION}"
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = Dir['lib/connectors/office365/**/*'].to_a +
                  Dir['lib/connectors/sharepoint/**/*'].to_a <<
                  'LICENSE'
  s.homepage    = 'https://elastic.co'
  s.license     = 'Elastic-2.0'

  s.add_dependency 'connectors_shared', VERSION
end
