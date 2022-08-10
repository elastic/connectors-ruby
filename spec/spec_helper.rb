# frozen_string_literal: true

require 'webmock/rspec'
require 'rack/test'
require 'active_support/time_with_zone'
require 'active_support/values/time_zone'
require 'active_support/core_ext/time/zones'
require 'simplecov'
require 'simplecov-material'

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

# Eneable coverage report
SimpleCov.add_filter('spec')
SimpleCov.formatter = SimpleCov::Formatter::MaterialFormatter
SimpleCov.start

$LOAD_PATH << '../lib'

def connectors_fixture_path(fixture_name)
  File.join('spec/fixtures', fixture_name)
end

def connectors_fixture_raw(fixture_name)
  File.read(connectors_fixture_path(fixture_name), :encoding => 'utf-8')
end

def connectors_fixture_binary(fixture_name)
  File.read(connectors_fixture_path(fixture_name), :mode => 'rb')
end

def connectors_fixture_json(fixture_name)
  JSON.parse(connectors_fixture_raw(fixture_name))
end

def get_class_specific_public_methods(klass)
  (klass.public_methods - Object.public_methods).sort
end

def random_string
  SecureRandom.hex
end

Time.zone = ActiveSupport::TimeZone.new('UTC')
ENV['APP_ENV'] = 'test'
