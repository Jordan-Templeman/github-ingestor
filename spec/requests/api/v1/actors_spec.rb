require 'rails_helper'

RSpec.describe 'Api::V1::Actors' do
  describe 'GET /api/v1/actors' do
    it 'returns JSON:API formatted response with correct record count' do
      create_list(:actor, 2)

      get api_v1_actors_path

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key('data')
      expect(json['data'].size).to eq(2)
    end

    it 'includes id, type, and attributes keys in each record' do
      create(:actor)

      get api_v1_actors_path

      record = response.parsed_body['data'].first
      expect(record).to have_key('id')
      expect(record).to have_key('type')
      expect(record).to have_key('attributes')
    end

    it 'includes expected attributes' do
      actor = create(:actor)

      get api_v1_actors_path

      attrs = response.parsed_body['data'].first['attributes']
      expect(attrs['github_id']).to eq(actor.github_id)
      expect(attrs['login']).to eq(actor.login)
      expect(attrs['display_login']).to eq(actor.display_login)
      expect(attrs['avatar_url']).to eq(actor.avatar_url)
      expect(attrs['url']).to eq(actor.url)
    end

    it 'paginates with limit and offset' do
      create_list(:actor, 5)

      get api_v1_actors_path, params: { page: { limit: 2, offset: 1 } }

      json = response.parsed_body
      expect(json['data'].size).to eq(2)
    end

    it 'enforces a maximum page limit' do
      create_list(:actor, 3)

      get api_v1_actors_path, params: { page: { limit: 1000 } }

      json = response.parsed_body
      expect(json['data'].size).to eq(3) # capped, not 1000
    end

    it 'defaults to a reasonable page size when no limit given' do
      create_list(:actor, 3)

      get api_v1_actors_path

      json = response.parsed_body
      expect(json['data'].size).to eq(3)
    end

    it 'returns an empty array when no actors exist' do
      get api_v1_actors_path

      json = response.parsed_body
      expect(json['data']).to eq([])
    end

    it 'filters by login with filter[login]' do
      create(:actor, login: 'alice')
      create(:actor, login: 'bob')

      get api_v1_actors_path, params: { filter: { login: 'alice' } }

      json = response.parsed_body
      expect(json['data'].size).to eq(1)
      expect(json['data'].first['attributes']['login']).to eq('alice')
    end
  end

  describe 'GET /api/v1/actors/:id' do
    it 'returns the actor in JSON:API format' do
      actor = create(:actor)

      get api_v1_actor_path(actor)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['data']['id']).to eq(actor.id.to_s)
      expect(json['data']['type']).to eq('actor')
      expect(json['data']['attributes']['login']).to eq(actor.login)
    end

    it 'returns 404 with JSON:API error body for missing actor' do
      get api_v1_actor_path(id: 999_999)

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json).to have_key('errors')
      expect(json['errors'].first['status']).to eq('404')
    end
  end
end
