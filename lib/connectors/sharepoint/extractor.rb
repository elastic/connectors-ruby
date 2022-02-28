#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/office365/extractor'
require 'connectors/sharepoint/adapter'

module Connectors
  module Sharepoint
    class Extractor < Connectors::Office365::Extractor

      private

      def convert_id_to_fp_id(id)
        Connectors::Sharepoint::Adapter.share_point_id_to_fp_id(id)
      end

      def adapter
        Connectors::Sharepoint::Adapter
      end

      def drives
        client.share_point_drives(:fields => %w(id owner name driveType))
      end
    end
  end
end
