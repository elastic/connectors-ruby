# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'ent-search-connectors'
  s.version     = '0.0.1' # TODO: keep version somewhere accessible from gemfile and Makefile
  s.summary     = 'Connectors Gem containing shared implementation of apis used by Enterprise Search'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = Dir.glob("lib/connectors_shared/*", File::FNM_DOTMATCH)
  s.homepage    =
    'https://elastic.co'
  s.license       = 'Nonstandard'
end
