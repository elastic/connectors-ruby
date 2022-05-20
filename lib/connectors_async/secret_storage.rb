#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module ConnectorsAsync
  class SecretStorage
    def initialize
      @storage = Concurrent::Hash.new
    end

    def store_secret(content_source_id, secret)
      @storage[content_source_id] = secret
    end

    def fetch_secret(content_source_id)
      @storage.fetch(content_source_id)
    end
  end
end
