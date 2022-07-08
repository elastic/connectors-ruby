require_relative 'lib/app/config'

Gem::Specification.new do |s|
  s.name        = 'connectors_utility'
  s.version     = App::Config['version']
  s.homepage    = 'https://github.com/elastic/connectors'
  s.summary     = 'Gem containing shared Connector Services libraries'
  s.description = ''
  s.authors     = ['Elastic']
  s.metadata    = {
    "revision" => App::Config['revision'],
    "repository" => App::Config['repository']
  }
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = %w[
                    LICENSE
                    NOTICE.txt
                    lib/connectors_utility.rb
                    lib/utility/elasticsearch/index/text_analysis_settings.rb
                    lib/utility/elasticsearch/index/mappings.rb
                    lib/utility/elasticsearch/index/language_data.yml
                  ]
  s.license     = 'Elastic-2.0'
end
