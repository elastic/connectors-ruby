# frozen_string_literal: true

require 'hashie/mash'
require 'connectors/gitlab/adapter'

describe Connectors::GitLab::Adapter do
  let(:project_hash) { Hashie::Mash.new(JSON.parse(connectors_fixture_raw('gitlab/simple_project.json'))) }

  context '#to_es_document' do
    it 'correctly produced the Enterprise Search ID' do
      new_id = described_class.gitlab_id_to_es_id(project_hash.id)
      expect(new_id).to include(project_hash.id.to_s)
      expect(new_id).to include('gitlab')
    end

    it 'fills in all the other data' do
      adapted = described_class.to_es_document(:project, project_hash)
      expect(adapted[:type]).to eq(:project)
      expect(adapted[:url]).to eq(project_hash[:web_url])
      expect(adapted[:body]).to eq(project_hash[:description])
      expect(adapted[:title]).to eq(project_hash[:name])
      expect(adapted[:namespace]).to eq(project_hash[:namespace][:name])
      expect(adapted[:created_at]).to eq(project_hash[:created_at])
      expect(adapted[:last_modified_at]).to eq(project_hash[:last_activity_at])
      expect(adapted[:visibility]).to eq(project_hash[:visibility])
    end

    context 'with permissions' do
      let(:permissions) { { :_allow_permissions => %w[something something_else] } }
      let(:project_with_permissions) { project_hash.merge(permissions) }

      # TODO permissions
      xit 'fills in permissions' do
        adapted = described_class.to_es_document(:project, project_with_permissions)
        expect(adapted[:_allow_permissions]).to eq(permissions[:_allow_permissions])
      end
    end
  end
end
