Gem::Specification.new do |s|
  s.name        = 'connectors_utility'
  s.version     = '0.1'
  s.homepage    = 'https://github.com/elastic/connectors'
  s.summary     = 'Gem containing shared Connector Services libraries'
  s.description = ''
  s.authors     = ['Elastic']
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = Dir.glob('lib/utility/elasticsearch/*', File::FNM_DOTMATCH) +
                  [
                    'LICENSE',
                    'NOTICE.txt',
                    'lib/connectors_utility.rb',
                    'lib/utility/elasticsearch/index/text_analysis_settings.rb',
                    'lib/utility/elasticsearch/index/mappings.rb'
                  ]
  s.license     = 'Elastic-2.0'
end
