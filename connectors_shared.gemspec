Gem::Specification.new do |s|
  s.name        = 'connectors_shared'
  s.version     = '0.0.1'
  s.summary     = "Connectors Gem containing shared implementation of apis used by Enterprise Search"
  s.description = ""
  s.authors     = ["Elastic"]
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = [
    "lib/connectors_shared/constants.rb",
    "lib/connectors_shared/errors.rb",
    "lib/connectors_shared/exception_tracking.rb",
    "lib/connectors_shared/logger.rb",
    "lib/connectors_shared/monitor.rb",
    "lib/stubs/swiftype/exception_tracking.rb",
    "lib/stubs/app_config.rb"
  ]
  s.homepage    =
    'https://elastic.co'
  s.license       = 'Nonstandard'
end
