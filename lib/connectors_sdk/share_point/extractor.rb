#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/extractor'
require 'connectors_sdk/share_point/adapter'

module ConnectorsSdk
  module SharePoint
    class Extractor < ConnectorsSdk::Office365::Extractor

      private

      def convert_id_to_fp_id(id)
        ConnectorsSdk::SharePoint::Adapter.share_point_id_to_fp_id(id)
      end

      def adapter
        ConnectorsSdk::SharePoint::Adapter
      end

      def drives
        client.share_point_drives(:fields => %w(id owner name driveType))
      end
    end
  end
end
