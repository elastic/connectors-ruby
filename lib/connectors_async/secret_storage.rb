
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# The class is actually supported for single-threaded usage EXCEPT for :documents field
# :documents are a Queue that's stated to be safe in a threaded environment
module ConnectorsAsync
  class SecretStorage
    def initialize
      @storage = Concurrent::Hash.new
    end

    def store_secret(secret)
      @storage["secret"] = secret
    end

    def fetch_secret()
      @storage["secret"]
    end
  end
end
