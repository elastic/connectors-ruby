#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true


module Connectors
  module Sharepoint
    class Authorization
      class << self
        def authorization_url
          'https://login.microsoftonline.com/common/oauth2/v2.0/authorize'
        end

        def token_credential_uri
          'https://login.microsoftonline.com/common/oauth2/v2.0/token'
        end

        def oauth_scope
          %w[
        User.ReadBasic.All
        Group.Read.All
        Directory.AccessAsUser.All
        Files.Read
        Files.Read.All
        Sites.Read.All
        offline_access
      ]
        end
      end
    end
  end
end
