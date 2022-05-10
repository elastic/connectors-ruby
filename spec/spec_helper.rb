# frozen_string_literal: true

require 'webmock/rspec'
require 'rack/test'
require 'hashie/mash'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/object/deep_dup'
require 'timecop'
require 'date'
require 'active_support/all'
require 'simplecov'
require 'simplecov-material'

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

def random_string
  SecureRandom.hex
end

Time.zone = ActiveSupport::TimeZone.new('UTC')
ENV['APP_ENV'] = 'test'
