Gem::Specification.new do |s|
  s.name        = 'connectors_shared'
  s.version     = '0.0.1'
  s.summary     = "Connectors Gem containing shared implementation of apis used by Enterprise Search"
  s.description = ""
  s.authors     = ["Elastic"]
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = [
    "connectors_shared/lib/connectors_shared/constants.rb",
    "connectors_shared/lib/connectors_shared/errors.rb",
    "connectors_shared/lib/connectors_shared/exception_tracking.rb",
    "connectors_shared/lib/connectors_shared/logger.rb",
    "connectors_shared/lib/connectors_shared/monitor.rb",
    "connectors_shared/lib/stubs/swiftype/exception_tracking.rb",
    "connectors_shared/lib/stubs/app_config.rb"
  ]
  s.homepage    =
    'https://elastic.co'
  s.license       = 'Nonstandard'
end
