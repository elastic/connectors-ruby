require_relative 'lib/connectors_shared/constants'

Gem::Specification.new do |s|
  s.name        = 'connectors_sdk'
  s.version     = ConnectorsShared::ConfigMetadata::VERSION
  s.homepage    = "https://github.com/elastic/connectors"
  s.summary     = 'Gem containing apis used by Enterprise Search and implementations of Connectors'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.metadata    = {
    "revision" => ConnectorsShared::ConfigMetadata::REVISION,
    "repository" => ConnectorsShared::ConfigMetadata::REPOSITORY
  }
  s.files       = Dir.glob("lib/connectors_sdk/**/*", File::FNM_DOTMATCH) +
    Dir.glob("lib/connectors_shared/**/*", File::FNM_DOTMATCH) +
    ['LICENSE', 'NOTICE.txt', 'lib/connectors_sdk.rb', 'lib/connectors_shared.rb']
  s.license       = 'Elastic-2.0'

  # TODO: figure out how to pin versions without harming ent-search repo
  s.add_dependency 'activesupport'
  s.add_dependency 'bson'
  s.add_dependency 'mime-types'
end
