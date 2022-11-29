#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'connectors/example/example_advanced_snippet_validator'
require 'core/filtering/validation_status'
require 'utility'

module Connectors
  module Example
    class Connector < Connectors::Base::Connector
      def self.service_type
        'example'
      end

      def self.display_name
        'Example Connector'
      end

      # Field 'Foo' won't have a default value. Field 'Bar' will have the default value 'Value'.
      def self.configurable_fields
        {
          'foo' => {
            'label' => 'Foo',
            'value' => nil
          },
          :bar => {
            :label => 'Bar',
            :value => 'Value'
          }
        }
      end

      def initialize(configuration: {}, job_description: nil)
        super
      end

      def do_health_check
        # Do the health check by trying to access 3rd-party system just to verify that everything is set up properly.
        #
        # To emulate unhealthy 3rd-party system situation, uncomment the following line:
        # raise 'something went wrong'
      end

      def self.advanced_snippet_validators
        ExampleAdvancedSnippetValidator
      end

      def yield_documents
        attachments = [
          load_attachment('first_attachment.txt'),
          load_attachment('second_attachment.txt'),
          load_attachment('third_attachment.txt'),
        ]

        attachments.each_with_index do |att, index|
          data = { id: (index + 1).to_s, name: "example document #{index + 1}", _attachment: File.read(att) }

          # Uncomment one of these two lines to simulate longer running sync jobs
          #
          # sleep(rand(10..60).seconds)
          # sleep(rand(1..10).minutes)

          yield data
        end
      end

      private

      def load_attachment(path)
        attachment_dir = "#{File.dirname(__FILE__)}/attachments"
        attachment_path = "#{attachment_dir}/#{path}"

        unless File.exist?(attachment_path)
          raise "Attachment at location '#{attachment_path}' doesn't exist. Attachments should be located under #{attachment_dir}"
        end

        File.open(attachment_path)
      end
    end
  end
end
