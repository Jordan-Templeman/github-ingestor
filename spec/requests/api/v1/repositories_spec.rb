require 'rails_helper'

RSpec.describe 'Api::V1::Repositories' do
  describe 'GET /api/v1/repositories' do
    it 'returns JSON:API formatted response with correct record count' do
      create_list(:repository, 2)

      get api_v1_repositories_path

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key('data')
      expect(json['data'].size).to eq(2)
    end

    it 'includes id, type, and attributes keys in each record' do
      create(:repository)

      get api_v1_repositories_path

      record = response.parsed_body['data'].first
      expect(record).to have_key('id')
      expect(record).to have_key('type')
      expect(record).to have_key('attributes')
    end

    it 'includes expected attributes' do
      repo = create(:repository)

      get api_v1_repositories_path

      attrs = response.parsed_body['data'].first['attributes']
      expect(attrs['github_id']).to eq(repo.github_id)
      expect(attrs['name']).to eq(repo.name)
      expect(attrs['full_name']).to eq(repo.full_name)
      expect(attrs['url']).to eq(repo.url)
    end

    it 'paginates with limit and offset' do
      create_list(:repository, 5)

      get api_v1_repositories_path, params: { page: { limit: 2, offset: 1 } }

      json = response.parsed_body
      expect(json['data'].size).to eq(2)
    end

    it 'enforces a maximum page limit' do
      create_list(:repository, 3)

      get api_v1_repositories_path, params: { page: { limit: 1000 } }

      json = response.parsed_body
      expect(json['data'].size).to eq(3)
    end

    it 'returns an empty array when no repositories exist' do
      get api_v1_repositories_path

      json = response.parsed_body
      expect(json['data']).to eq([])
    end

    it 'filters by name with filter[name]' do
      create(:repository, name: 'cool-app')
      create(:repository, name: 'other-app')

      get api_v1_repositories_path, params: { filter: { name: 'cool-app' } }

      json = response.parsed_body
      expect(json['data'].size).to eq(1)
      expect(json['data'].first['attributes']['name']).to eq('cool-app')
    end
  end

  describe 'GET /api/v1/repositories/:id' do
    it 'returns the repository in JSON:API format' do
      repo = create(:repository)

      get api_v1_repository_path(repo)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['data']['id']).to eq(repo.id.to_s)
      expect(json['data']['type']).to eq('repository')
      expect(json['data']['attributes']['name']).to eq(repo.name)
    end

    it 'returns 404 with JSON:API error body for missing repository' do
      get api_v1_repository_path(id: 999_999)

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json).to have_key('errors')
      expect(json['errors'].first['status']).to eq('404')
    end
  end
end
