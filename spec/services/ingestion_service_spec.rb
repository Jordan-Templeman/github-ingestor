require 'rails_helper'

RSpec.describe IngestionService do
  let(:actor_id)       { 260_153_069 }
  let(:actor_login)    { 'octocat' }
  let(:repo_id)        { 1_154_170_983 }
  let(:repo_name)      { 'octocat/hello-world' }
  let(:push_event_id)  { '9143965344' }
  let(:push_ref)       { 'refs/heads/main' }
  let(:push_head)      { '7ad244f9d4ca8631675cb6af4f3bf792f120b146' }
  let(:push_before)    { 'e440659007c4b6da4b7b0d754fd59eae83b58fc9' }
  let(:push_id)        { 31_437_670_048 }

  let(:push_event_payload) do
    {
      'id' => push_event_id,
      'type' => 'PushEvent',
      'actor' => {
        'id' => actor_id,
        'login' => actor_login,
        'display_login' => actor_login,
        'gravatar_id' => '',
        'url' => "https://api.github.com/users/#{actor_login}",
        'avatar_url' => "https://avatars.githubusercontent.com/u/#{actor_id}?",
      },
      'repo' => {
        'id' => repo_id,
        'name' => repo_name,
        'url' => "https://api.github.com/repos/#{repo_name}",
      },
      'payload' => {
        'repository_id' => repo_id,
        'push_id' => push_id,
        'ref' => push_ref,
        'head' => push_head,
        'before' => push_before,
      },
      'public' => true,
      'created_at' => '2026-03-07T17:25:39Z',
    }
  end

  let(:issues_event_payload) do
    {
      'id' => '9143965345',
      'type' => 'IssuesEvent',
      'actor' => {
        'id' => 260_153_070,
        'login' => 'testuser',
        'display_login' => 'testuser',
        'gravatar_id' => '',
        'url' => 'https://api.github.com/users/testuser',
        'avatar_url' => 'https://avatars.githubusercontent.com/u/260153070?',
      },
      'repo' => {
        'id' => 1_154_170_984,
        'name' => 'testuser/some-repo',
        'url' => 'https://api.github.com/repos/testuser/some-repo',
      },
      'payload' => {},
      'public' => true,
      'created_at' => '2026-03-07T17:25:40Z',
    }
  end

  let(:events) { [push_event_payload, issues_event_payload] }

  before do
    allow(GithubEventsClient).to receive(:fetch).and_return(events)
  end

  describe '.run' do
    it 'fetches events from GithubEventsClient' do
      described_class.run
      expect(GithubEventsClient).to have_received(:fetch)
    end

    it 'filters to only PushEvents' do
      described_class.run
      expect(PushEvent.count).to eq(1)
    end

    it 'creates an Actor record from the event' do
      expect { described_class.run }.to change(Actor, :count).by(1)

      actor = Actor.find_by(github_id: actor_id)
      expect(actor.login).to eq(actor_login)
      expect(actor.display_login).to eq(actor_login)
      expect(actor.avatar_url).to eq("https://avatars.githubusercontent.com/u/#{actor_id}?")
      expect(actor.url).to eq("https://api.github.com/users/#{actor_login}")
    end

    it 'creates a Repository record from the event' do
      expect { described_class.run }.to change(Repository, :count).by(1)

      repo = Repository.find_by(github_id: repo_id)
      expect(repo.name).to eq(repo_name)
      expect(repo.url).to eq("https://api.github.com/repos/#{repo_name}")
    end

    it 'persists a PushEvent with correct git references' do
      described_class.run

      push_event = PushEvent.find_by(github_id: push_event_id)
      expect(push_event).to be_present
      expect(push_event.ref).to eq(push_ref)
      expect(push_event.head).to eq(push_head)
      expect(push_event.before).to eq(push_before)
    end

    it 'stores the push_id and raw_payload on the PushEvent' do
      described_class.run

      push_event = PushEvent.find_by(github_id: push_event_id)
      expect(push_event.push_id).to eq(push_id)
      expect(push_event.raw_payload).to eq(push_event_payload)
    end

    it 'associates the PushEvent with the correct Actor and Repository' do
      described_class.run

      push_event = PushEvent.find_by(github_id: push_event_id)
      expect(push_event.actor.github_id).to eq(actor_id)
      expect(push_event.repository.github_id).to eq(repo_id)
    end

    context 'when the same event is ingested twice' do
      before { described_class.run }

      it 'skips duplicates on re-run (idempotent)' do
        expect { described_class.run }.not_to change(PushEvent, :count)
      end

      it 'does not create duplicate Actor records' do
        expect { described_class.run }.not_to change(Actor, :count)
      end

      it 'does not create duplicate Repository records' do
        expect { described_class.run }.not_to change(Repository, :count)
      end
    end

    context 'when multiple push events share the same actor' do
      let(:second_push_event) do
        push_event_payload.merge(
          'id' => '9143965346',
          'payload' => push_event_payload['payload'].merge(
            'push_id' => 31_437_670_049,
            'head' => 'abc123',
            'before' => 'def456'
          )
        )
      end

      let(:events) { [push_event_payload, second_push_event] }

      it 'reuses the existing Actor record' do
        expect { described_class.run }.to change(Actor, :count).by(1)
        expect(PushEvent.count).to eq(2)
      end
    end

    it 'logs the ingestion summary' do
      expect(Rails.logger).to receive(:info).with(
        /\[IngestionService\].*fetched=2.*push_events=1.*persisted=1.*skipped=0/
      )
      described_class.run
    end

    context 'when all events are non-push' do
      let(:events) { [issues_event_payload] }

      it 'persists nothing' do
        expect { described_class.run }.not_to change(PushEvent, :count)
      end

      it 'logs zero counts' do
        expect(Rails.logger).to receive(:info).with(
          /\[IngestionService\].*push_events=0.*persisted=0/
        )
        described_class.run
      end
    end

    context 'when GithubEventsClient returns an empty array' do
      let(:events) { [] }

      it 'handles gracefully with no errors' do
        expect { described_class.run }.not_to raise_error
      end
    end

    context 'when GithubEventsClient raises an error' do
      before do
        allow(GithubEventsClient).to receive(:fetch)
          .and_raise(GithubEventsClient::ApiError, 'GitHub API error: 502 Bad Gateway')
      end

      it 'propagates the error to the caller' do
        expect { described_class.run }.to raise_error(GithubEventsClient::ApiError, /502/)
      end
    end
  end
end
