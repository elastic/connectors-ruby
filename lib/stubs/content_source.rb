#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'stubs/service_type'

class ContentSource
  attr_reader :access_token

  def initialize(access_token: 'BEARER A BEAR')
    @access_token = access_token
  end

  def authorization_details
    {
      :expires_at => Time.now
    }
  end

  def authorization_details!; end

  def service_type
    ServiceType.new
  end
end
