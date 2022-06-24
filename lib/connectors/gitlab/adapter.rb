# frozen_string_literal: true

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
require 'hashie/mash'
require 'active_support/core_ext/hash/indifferent_access'
require 'connectors/base/adapter'

module Connectors
  module GitLab
    class Adapter < Connectors::Base::Adapter
      # it's important to have this to generate ID converters between the GitLab ID and the
      # Enterprise Search document ID. The Enterprise Search document ID will be prefixed with the service type,
      # in our case - `gitlab`.
      generate_id_helpers :gitlab, 'gitlab'

      def self.to_es_document(type, source_doc)
        source_doc = source_doc.with_indifferent_access
        result = {}
        case type.to_sym
        when :project
          result.merge!(
            {
              :url => source_doc[:web_url],
              :body => source_doc[:description],
              :title => source_doc[:name],
              :created_at => source_doc[:created_at],
              :last_modified_at => source_doc[:last_activity_at],
              :visibility => source_doc[:visibility],
              :namespace => if source_doc[:namespace].nil?
                              nil
                            else
                              source_doc[:namespace][:name]
                            end
            })
        else
          # don't remap
          result.merge!(source_doc)
        end
        result[:id] = gitlab_id_to_es_id(source_doc[:id])
        result[:type] = type
        result
      end
    end
  end
end
