# frozen_string_literal: true

require 'connectors/sharepoint/sharepoint'

# TODO do proper mocking
class Dup
  attr_reader :deep_dup

  def initialize
    @deep_dup = {}
  end
end

class Config
  attr_reader :cursors

  def initialize
    @cursors = Dup.new
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
