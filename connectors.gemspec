puts "WADUP"
require_relative 'lib/app/config'
puts "WAAAT"

Gem::Specification.new do |s|
  s.name        = 'connectors'
  s.version     = App::Config['version']
  s.homepage    = "https://github.com/elastic/connectors"
  s.summary     = 'Gem containing apis used by Enterprise Search and implementations of Connectors'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.metadata    = {
    "revision" => App::Config['revision'],
    "repository" => App::Config['repository']
  }
  s.files       = Dir.glob("lib/connectors/**/*", File::FNM_DOTMATCH) +
    Dir.glob("lib/utility/**/*", File::FNM_DOTMATCH) +
    [
      'LICENSE',
      'NOTICE.txt',
      'lib/connectors.rb',
      'lib/utility.rb'
    ]
  s.license     = 'Elastic-2.0'

  # TODO: figure out how to pin versions without harming ent-search repo
  s.add_dependency 'activesupport'
  s.add_dependency 'bson'
  s.add_dependency 'mime-types'
  s.add_dependency 'tzinfo-data'
  s.add_dependency 'nokogiri'

  # Dependencies for the HTTP service
  s.add_dependency 'forwardable'
  s.add_dependency 'faraday'
  s.add_dependency 'faraday_middleware'
  s.add_dependency 'httpclient'
  s.add_dependency 'hashie'

  # Dependencies for oauth
  s.add_dependency 'signet'
end
