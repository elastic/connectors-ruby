
Gem::Specification.new do |s|
  s.name        = 'connectors_utility'
  s.version     = File.read('VERSION').strip
  s.homepage    = 'https://github.com/elastic/connectors-ruby'
  s.summary     = 'Gem containing shared Connector Services libraries'
  s.description = ''
  s.authors     = ['Elastic']
  s.metadata    = {
    "revision" => `git rev-parse HEAD`.strip,
    "repository" => 'https://github.com/elastic/connectors-ruby'
  }
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = %w[
                    LICENSE
                    NOTICE.txt
                    lib/connectors_utility.rb
                    lib/utility/es_client.rb
                    lib/utility/logger.rb
                    lib/utility/bulk_queue.rb
                    lib/utility/common.rb
                    lib/utility/constants.rb
                    lib/utility/cron.rb
                    lib/utility/errors.rb
                    lib/utility/es_client.rb
                    lib/utility/environment.rb
                    lib/utility/error_monitor.rb
                    lib/utility/exception_tracking.rb
                    lib/utility/extension_mapping_util.rb
                    lib/utility/filtering.rb
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
                    lib/core/connector_job.rb
                    lib/core/filtering/validation_status.rb
                    lib/connectors/job_trigger_method.rb
                  ]
  s.license     = 'Elastic-2.0'
  s.add_dependency 'activesupport', '>= 5.2'
  s.add_dependency 'ecs-logging', '~> 1.0.0'
  s.add_dependency 'fugit', '~> 1.11', '>= 1.11.1'
  s.add_dependency 'mime-types', '~> 3.6'
  s.add_dependency 'tzinfo'
  s.add_dependency 'tzinfo-data'
end
