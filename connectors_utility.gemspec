require_relative 'lib/app/config'

Gem::Specification.new do |s|
  s.name        = 'connectors_utility'
  s.version     = App::Config[:version]
  s.homepage    = 'https://github.com/elastic/connectors-ruby'
  s.summary     = 'Gem containing shared Connector Services libraries'
  s.description = ''
  s.authors     = ['Elastic']
  s.metadata    = {
    "revision" => App::Config[:revision],
    "repository" => App::Config[:repository]
  }
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = %w[
                    LICENSE
                    NOTICE.txt
                    lib/connectors_utility.rb
                    lib/utility/es_client.rb
                    lib/utility/logger.rb
                    lib/utility/constants.rb
                    lib/utility/cron.rb
                    lib/utility/errors.rb
                    lib/utility/es_client.rb
                    lib/utility/environment.rb
                    lib/utility/exception_tracking.rb
                    lib/utility/extension_mapping_util.rb
                    lib/utility/logger.rb
                    lib/utility.rb
                    lib/utility/elasticsearch/index/text_analysis_settings.rb
                    lib/utility/elasticsearch/index/mappings.rb
                    lib/utility/elasticsearch/index/language_data.yml
                    lib/connectors/sync_status.rb
                    lib/core/scheduler.rb
                    lib/connectors/connector_status.rb
                    lib/connectors/crawler/scheduler.rb
                    lib/core/elastic_connector_actions.rb
                    lib/core/connector_settings.rb
                  ]
  s.license     = 'Elastic-2.0'
  s.add_runtime_dependency 'fugit'
end
