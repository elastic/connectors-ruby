# frozen_string_literal: true

ruby File.read(File.join(__dir__, '.ruby-version')).strip

# Pull gem index from rubygems
source 'https://rubygems.org'

# Pin the version of bundle we support
gem 'bundler', File.read(File.join(__dir__, '.bundler-version')).strip

# Dependencies for connectors
gem 'activesupport'
gem 'mime-types', '3.4.1'
gem 'tzinfo-data'
gem 'tzinfo'
gem 'nokogiri'
gem 'fugit'
gem 'remedy'
gem 'ecs-logging'

# Remove this section when gem 'config' is removed
gem 'dry-container'
gem 'dry-core'
gem 'dry-configurable'
gem 'dry-initializer'
gem 'dry-inflector'
gem 'dry-schema'
gem 'dry-validation'

group :test do
  gem 'rspec-collection_matchers', '~> 1.2.0'
  gem 'rspec-core', '~> 3.10.1'
  gem 'rspec_junit_formatter'
  gem 'rubocop', '1.18.4'
  gem 'rubocop-performance', '1.11.5'
  gem 'rspec-mocks'
  gem 'webmock'
  gem 'rack', '>= 2.2.3.1'
  gem 'rack-test'
  gem 'ruby-debug-ide'
  gem 'pry-remote'
  gem 'pry-nav'
  gem 'debase', '0.2.5.beta2'
  gem 'timecop'
  gem 'simplecov', require: false
  gem 'simplecov-material'
end

# Dependencies for the HTTP service
gem 'config'
gem 'forwardable'
gem 'faraday'
gem 'faraday_middleware'
gem 'httpclient'
gem 'attr_extras'
gem 'hashie'
gem 'concurrent-ruby'
gem 'elasticsearch'

# Dependencies for oauth
gem 'signet'

# Dependency for mongo connector
gem 'mongo'
