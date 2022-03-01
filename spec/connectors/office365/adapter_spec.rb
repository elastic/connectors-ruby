#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/office365/adapter'

describe Connectors::Office365::Adapter do
  it 'is not a concrete class' do
    expect { described_class.swiftype_document_from_folder(nil) }.to raise_error(NotImplementedError)
  end
end
