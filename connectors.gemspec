Gem::Specification.new do |s|
  s.name        = 'connectors'
  s.version     = '0.0.1'
  s.summary     = "Connectors Gem containing shared implementation of apis used by Enterprise Search"
  s.description = ""
  s.authors     = ["Elastic"]
  s.email       = 'ent-search-dev@elastic.co'
  s.files       = [
    "connectors/lib/connectors/constants.rb",
    "connectors/lib/connectors/errors.rb",
    "connectors/lib/connectors/exception_tracking.rb",
    "connectors/lib/connectors/logger.rb",
    "connectors/lib/connectors/monitor.rb",
    "connectors/lib/stubs/swiftype/exception_tracking.rb",
    "connectors/lib/stubs/app_config.rb"
  ]
  s.homepage    =
    'https://elastic.co'
  s.license       = 'Nonstandard'
end
