require 'rails_helper'

RSpec.describe 'Api::V1::PushEvents' do
  describe 'GET /api/v1/push_events' do
    it 'returns JSON:API formatted response with correct record count' do
      create_list(:push_event, 2)

      get api_v1_push_events_path

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key('data')
      expect(json['data'].size).to eq(2)
    end

    it 'includes id, type, and attributes keys in each record' do
      create(:push_event)

      get api_v1_push_events_path

      record = response.parsed_body['data'].first
      expect(record).to have_key('id')
      expect(record).to have_key('type')
      expect(record).to have_key('attributes')
    end

    it 'includes expected attributes' do
      event = create(:push_event)

      get api_v1_push_events_path

      attrs = response.parsed_body['data'].first['attributes']
      expect(attrs['github_id']).to eq(event.github_id)
      expect(attrs['ref']).to eq(event.ref)
      expect(attrs['head']).to eq(event.head)
      expect(attrs['before']).to eq(event.before)
      expect(attrs['push_id']).to eq(event.push_id)
    end

    it 'includes actor and repository relationships' do
      create(:push_event)

      get api_v1_push_events_path

      relationships = response.parsed_body['data'].first['relationships']
      expect(relationships).to have_key('actor')
      expect(relationships).to have_key('repository')
    end

    it 'paginates with limit and offset' do
      create_list(:push_event, 5)

      get api_v1_push_events_path, params: { page: { limit: 2, offset: 1 } }

      json = response.parsed_body
      expect(json['data'].size).to eq(2)
    end

    it 'enforces a maximum page limit' do
      create_list(:push_event, 3)

      get api_v1_push_events_path, params: { page: { limit: 1000 } }

      json = response.parsed_body
      expect(json['data'].size).to eq(3)
    end

    it 'returns an empty array when no push events exist' do
      get api_v1_push_events_path

      json = response.parsed_body
      expect(json['data']).to eq([])
    end

    it 'filters by ref with filter[ref]' do
      create(:push_event, ref: 'refs/heads/main')
      create(:push_event, ref: 'refs/heads/develop')

      get api_v1_push_events_path, params: { filter: { ref: 'refs/heads/main' } }

      json = response.parsed_body
      expect(json['data'].size).to eq(1)
      expect(json['data'].first['attributes']['ref']).to eq('refs/heads/main')
    end

    it 'filters by actor login with filter[actor]' do
      alice = create(:actor, login: 'alice')
      bob = create(:actor, login: 'bob')
      create(:push_event, actor: alice)
      create(:push_event, actor: bob)

      get api_v1_push_events_path, params: { filter: { actor: 'alice' } }

      json = response.parsed_body
      expect(json['data'].size).to eq(1)
    end

    it 'filters by repository name with filter[repository]' do
      cool_repo = create(:repository, name: 'cool-app')
      other_repo = create(:repository, name: 'other-app')
      create(:push_event, repository: cool_repo)
      create(:push_event, repository: other_repo)

      get api_v1_push_events_path, params: { filter: { repository: 'cool-app' } }

      json = response.parsed_body
      expect(json['data'].size).to eq(1)
    end

    it 'ignores unknown filter params' do
      create(:push_event)

      get api_v1_push_events_path, params: { filter: { unknown: 'value' } }

      json = response.parsed_body
      expect(json['data'].size).to eq(1)
    end
  end

  describe 'GET /api/v1/push_events/:id' do
    it 'returns the push event in JSON:API format' do
      event = create(:push_event)

      get api_v1_push_event_path(event)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['data']['id']).to eq(event.id.to_s)
      expect(json['data']['type']).to eq('push_event')
      expect(json['data']['attributes']['ref']).to eq(event.ref)
    end

    it 'returns 404 with JSON:API error body for missing push event' do
      get api_v1_push_event_path(id: 999_999)

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json).to have_key('errors')
      expect(json['errors'].first['status']).to eq('404')
    end
  end
end
