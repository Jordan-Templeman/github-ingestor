require 'rails_helper'

RSpec.describe GithubEventsClient do
  let(:events_url)    { "#{GithubEventsClient::BASE_URL}#{GithubEventsClient::EVENTS_PATH}" }

  let(:push_event_id) { '9143965344' }
  let(:actor_login)   { 'octocat' }
  let(:actor_id)      { 260_153_069 }
  let(:repo_name)     { 'octocat/hello-world' }
  let(:repo_id)       { 1_154_170_983 }
  let(:push_ref)      { 'refs/heads/main' }
  let(:push_head)     { '7ad244f9d4ca8631675cb6af4f3bf792f120b146' }
  let(:push_before)   { 'e440659007c4b6da4b7b0d754fd59eae83b58fc9' }
  let(:push_id)       { 31_437_670_048 }

  let(:sample_events) do
    [
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
      },
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
      },
    ]
  end

  describe '.fetch' do
    context 'when the API returns 200' do
      let(:rate_limit_remaining) { '58' }

      before do
        stub_request(:get, events_url)
          .with(headers: {
                  'Accept' => 'application/vnd.github+json',
                  'User-Agent' => 'StrongMind-GitHub-Ingestor',
                })
          .to_return(
            status: 200,
            body: sample_events.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'X-RateLimit-Remaining' => rate_limit_remaining,
              'X-RateLimit-Reset' => '1700000000',
            }
          )
      end

      it 'returns the parsed event array' do
        events = described_class.fetch
        expect(events).to be_an(Array)
        expect(events.length).to eq(2)
        expect(events.first['id']).to eq(push_event_id)
        expect(events.first['type']).to eq('PushEvent')
      end

      it 'logs the request url, status, and rate limit remaining' do
        expect(Rails.logger).to receive(:info).with(
          /\[GithubEventsClient\].*GET.*events.*status=200.*rate_limit_remaining=#{rate_limit_remaining}/
        )
        described_class.fetch
      end
    end

    context 'when the API returns an empty event list' do
      before do
        stub_request(:get, events_url)
          .to_return(
            status: 200,
            body: '[]',
            headers: {
              'Content-Type' => 'application/json',
              'X-RateLimit-Remaining' => '58',
            }
          )
      end

      it 'returns an empty array' do
        expect(described_class.fetch).to eq([])
      end
    end

    context 'when rate limit headers are absent' do
      before do
        stub_request(:get, events_url)
          .to_return(
            status: 200,
            body: sample_events.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the parsed response without raising' do
        expect { described_class.fetch }.not_to raise_error
      end
    end

    context 'when X-RateLimit-Remaining is 0' do
      before do
        stub_request(:get, events_url)
          .to_return(
            status: 200,
            body: sample_events.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'X-RateLimit-Remaining' => '0',
              'X-RateLimit-Reset' => '1700000000',
            }
          )
      end

      it 'raises RateLimitedError with reset timestamp' do
        expect { described_class.fetch }.to raise_error(
          GithubEventsClient::RateLimitedError,
          /rate limit exhausted.*resets at/i
        )
      end

      it 'logs the rate limit exhaustion' do
        expect(Rails.logger).to receive(:warn).with(/\[GithubEventsClient\].*rate limit exhausted/i)
        expect { described_class.fetch }.to raise_error(GithubEventsClient::RateLimitedError)
      end
    end

    context 'when the API returns 429' do
      let(:retry_after) { '60' }

      before do
        stub_request(:get, events_url)
          .to_return(
            status: 429,
            body: { message: 'API rate limit exceeded' }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Retry-After' => retry_after,
              'X-RateLimit-Remaining' => '0',
              'X-RateLimit-Reset' => '1700000000',
            }
          )
      end

      it 'raises RateLimitedError with retry-after value' do
        expect { described_class.fetch }.to raise_error(
          GithubEventsClient::RateLimitedError,
          /retry after #{retry_after}s/
        )
      end

      it 'logs the 429 response with retry-after' do
        expect(Rails.logger).to receive(:warn).with(/\[GithubEventsClient\].*429.*retry-after=#{retry_after}/i)
        expect { described_class.fetch }.to raise_error(GithubEventsClient::RateLimitedError)
      end
    end

    context 'when the API returns a non-200/429 error' do
      let(:error_status) { 502 }

      before do
        stub_request(:get, events_url)
          .to_return(
            status: error_status,
            body: 'Bad Gateway',
            headers: { 'X-RateLimit-Remaining' => '55' }
          )
      end

      it 'raises an ApiError with the status code' do
        expect { described_class.fetch }.to raise_error(
          GithubEventsClient::ApiError,
          /#{error_status}/
        )
      end
    end
  end
end
