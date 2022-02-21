# frozen_string_literal: true
require 'active_support/core_ext/object/deep_dup'
require 'connectors/sharepoint/sharepoint'

# TODO do proper mocking
class Config
  attr_reader :cursors

  def initialize
    @cursors = {}   
  end

  def index_all_drives?
    true
  end
end

RSpec.describe Sharepoint::HttpCallWrapper do
  let(:backend) do
    described_class.new(Config.new)
  end

  it 'can get documents' do
    backend.get_document_batch
  end
end
