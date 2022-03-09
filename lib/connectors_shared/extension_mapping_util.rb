#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash'

module ConnectorsShared
  class ExtensionMappingUtil
    @extension_to_mime = {
      :doc => %w[
        application/x-tika-msoffice
        application/msword
      ].freeze,
      :docx => %w[
        application/x-tika-ooxml
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/vnd.openxmlformats-officedocument.wordprocessingml.template
        application/vnd.ms-word.template.macroenabled.12
        application/vnd.ms-word.document.macroenabled.12
      ].freeze,
      :html => %w[
        text/html
        application/xhtml+xml
      ].freeze,
      :odt => %w[
        application/x-vnd.oasis.opendocument.graphics-template
        application/vnd.sun.xml.writer application/x-vnd.oasis.opendocument.text
        application/x-vnd.oasis.opendocument.text-web
        application/x-vnd.oasis.opendocument.spreadsheet-template
        application/vnd.oasis.opendocument.formula-template
        application/vnd.oasis.opendocument.presentation
        application/vnd.oasis.opendocument.image-template
        application/x-vnd.oasis.opendocument.graphics
        application/vnd.oasis.opendocument.chart-template
        application/vnd.oasis.opendocument.presentation-template
        application/x-vnd.oasis.opendocument.image-template
        application/vnd.oasis.opendocument.formula
        application/x-vnd.oasis.opendocument.image
        application/vnd.oasis.opendocument.spreadsheet-template
        application/x-vnd.oasis.opendocument.chart-template
        application/x-vnd.oasis.opendocument.formula
        application/vnd.oasis.opendocument.spreadsheet
        application/vnd.oasis.opendocument.text-web
        application/vnd.oasis.opendocument.text-template
        application/vnd.oasis.opendocument.text
        application/x-vnd.oasis.opendocument.formula-template
        application/x-vnd.oasis.opendocument.spreadsheet
        application/x-vnd.oasis.opendocument.chart
        application/vnd.oasis.opendocument.text-master
        application/x-vnd.oasis.opendocument.text-master
        application/x-vnd.oasis.opendocument.text-template
        application/vnd.oasis.opendocument.graphics
        application/vnd.oasis.opendocument.graphics-template
        application/x-vnd.oasis.opendocument.presentation
        application/vnd.oasis.opendocument.image
        application/x-vnd.oasis.opendocument.presentation-template
        application/vnd.oasis.opendocument.chart
      ].freeze,
      :one => %w[
        application/onenote
        application/msonenote
      ].freeze,
      :pdf => %w[
        application/pdf
      ].freeze,
      :ppt => %w[
        application/vnd.ms-powerpoint
      ].freeze,
      :pptx => %w[
        application/vnd.openxmlformats-officedocument.presentationml.presentation
        application/vnd.ms-powerpoint.presentation.macroenabled.12
        application/vnd.openxmlformats-officedocument.presentationml.template
        application/vnd.ms-powerpoint.slideshow.macroenabled.12
        application/vnd.ms-powerpoint.addin.macroenabled.12
        application/vnd.openxmlformats-officedocument.presentationml.slideshow
      ].freeze,
      :rtf => %w[
        message/richtext
        text/richtext
        text/rtf
        application/rtf
      ].freeze,
      :txt => %w[
        text/plain
      ].freeze,
      :xls => %w[
        application/x-tika-msoffice
        application/vnd.ms-excel
        application/vnd.ms-excel.sheet.3
        application/vnd.ms-excel.sheet.2
        application/vnd.ms-excel.workspace.3
        application/vnd.ms-excel.workspace.4
        application/vnd.ms-excel.sheet.4
      ].freeze,
      :xlsx => %w[
        application/x-tika-ooxml
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
        application/vnd.openxmlformats-officedocument.spreadsheetml.template
        application/vnd.ms-excel.addin.macroenabled.12
        application/vnd.ms-excel.template.macroenabled.12
        application/vnd.ms-excel.sheet.macroenabled.12
      ].freeze
    }.with_indifferent_access.freeze

    def self.mime_to_extension
      @mime_to_extension ||= @extension_to_mime.each_with_object({}) do |(key, values), memo|
        values.each { |value| memo[value] = key.to_s }
      end.with_indifferent_access.freeze
    end

    def self.get_extension(mime_type)
      mime_to_extension[mime_type.to_s.downcase]
    end

    def self.get_mime_types(extension)
      @extension_to_mime[extension.to_s.downcase]
    end
  end
end
