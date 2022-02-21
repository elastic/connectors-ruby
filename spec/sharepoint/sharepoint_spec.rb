require 'connectors/sharepoint/sharepoint'

RSpec.describe Sharepoint::HttpCallWrapper do
  it "can get documents" do

    backend = Sharepoint::HttpCallWrapper.new
    backend.get_document_batch
  end
end
