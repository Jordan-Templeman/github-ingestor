require 'rails_helper'

RSpec.describe EnrichmentService do
  let(:actor_url)  { 'https://api.github.com/users/octocat' }
  let(:repo_url)   { 'https://api.github.com/repos/octocat/hello-world' }

  let(:actor_detail) do
    {
      'id' => 260_153_069,
      'login' => 'octocat',
      'name' => 'The Octocat',
      'company' => 'GitHub',
      'blog' => 'https://github.blog',
      'location' => 'San Francisco',
      'bio' => 'An octocat',
      'public_repos' => 8,
      'followers' => 10_000,
    }
  end

  let(:repo_detail) do
    {
      'id' => 1_154_170_983,
      'name' => 'hello-world',
      'full_name' => 'octocat/hello-world',
      'description' => 'My first repository on GitHub!',
      'language' => 'Ruby',
      'stargazers_count' => 2000,
      'forks_count' => 500,
    }
  end

  let(:actor)      { create(:actor, login: 'octocat', url: actor_url, raw_payload: nil) }
  let(:repository) { create(:repository, name: 'octocat/hello-world', url: repo_url, raw_payload: nil) }
  let(:push_event) { create(:push_event, actor: actor, repository: repository) }

  before do
    stub_request(:get, actor_url)
      .with(headers: GithubApiConfig::HEADERS)
      .to_return(
        status: 200,
        body: actor_detail.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, repo_url)
      .with(headers: GithubApiConfig::HEADERS)
      .to_return(
        status: 200,
        body: repo_detail.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    allow(AvatarDownloadService).to receive(:download)
  end

  describe '.enrich' do
    it 'fetches and stores actor raw_payload' do
      described_class.enrich(push_event)
      expect(actor.reload.raw_payload).to eq(actor_detail)
    end

    it 'fetches and stores repository raw_payload' do
      described_class.enrich(push_event)
      expect(repository.reload.raw_payload).to eq(repo_detail)
    end

    it 'logs the enrichment actions' do
      expect(Rails.logger).to receive(:info).with(
        /\[EnrichmentService\].*Enriched actor.*octocat/
      )
      expect(Rails.logger).to receive(:info).with(
        %r{\[EnrichmentService\].*Enriched repository.*octocat/hello-world}
      )
      described_class.enrich(push_event)
    end

    it 'calls AvatarDownloadService after enriching actor' do
      allow(AvatarDownloadService).to receive(:download)

      described_class.enrich(push_event)

      expect(AvatarDownloadService).to have_received(:download).with(actor)
    end

    context 'when avatar download fails, enrichment still succeeds' do
      before do
        allow(AvatarDownloadService).to receive(:download).and_raise(StandardError, 'CDN down')
      end

      it 'does not crash and still enriches the repository' do
        allow(Rails.logger).to receive(:error)
        expect { described_class.enrich(push_event) }.not_to raise_error
        expect(repository.reload.raw_payload).to eq(repo_detail)
      end
    end

    context 'when actor raw_payload is already present' do
      let(:actor) { create(:actor, url: actor_url, raw_payload: { 'cached' => true }) }

      it 'skips the actor API call' do
        described_class.enrich(push_event)
        expect(a_request(:get, actor_url)).not_to have_been_made
      end

      it 'logs the skip' do
        expect(Rails.logger).to receive(:info).with(
          /\[EnrichmentService\].*Skipped actor.*already enriched/
        )
        allow(Rails.logger).to receive(:info)
        described_class.enrich(push_event)
      end
    end

    context 'when repository raw_payload is already present' do
      let(:repository) { create(:repository, url: repo_url, raw_payload: { 'cached' => true }) }

      it 'skips the repository API call' do
        described_class.enrich(push_event)
        expect(a_request(:get, repo_url)).not_to have_been_made
      end

      it 'logs the skip' do
        expect(Rails.logger).to receive(:info).with(
          /\[EnrichmentService\].*Skipped repository.*already enriched/
        )
        allow(Rails.logger).to receive(:info)
        described_class.enrich(push_event)
      end
    end

    context 'when the actor API call fails' do
      before do
        stub_request(:get, actor_url).to_return(status: 500, body: 'Internal Server Error')
      end

      it 'logs the error and does not crash' do
        expect(Rails.logger).to receive(:error).with(
          /\[EnrichmentService\].*Failed to enrich actor/
        )
        allow(Rails.logger).to receive(:info)
        expect { described_class.enrich(push_event) }.not_to raise_error
      end

      it 'still enriches the repository' do
        allow(Rails.logger).to receive(:error)
        described_class.enrich(push_event)
        expect(repository.reload.raw_payload).to eq(repo_detail)
      end
    end

    context 'when the actor API call raises a network error' do
      before do
        stub_request(:get, actor_url).to_raise(SocketError.new('getaddrinfo: Name or service not known'))
      end

      it 'does not crash and still enriches the repository' do
        allow(Rails.logger).to receive(:error)
        expect { described_class.enrich(push_event) }.not_to raise_error
        expect(repository.reload.raw_payload).to eq(repo_detail)
      end
    end

    context 'when an actor URL is not a GitHub API URL' do
      let(:actor) do
        create(:actor, login: 'octocat', url: 'http://evil.example.com/ssrf', raw_payload: nil)
      end

      it 'blocks the request and logs the rejection' do
        expect(Rails.logger).to receive(:error).with(
          /\[EnrichmentService\].*Blocked non-GitHub URL/
        )
        allow(Rails.logger).to receive(:info)
        described_class.enrich(push_event)
        expect(actor.reload.raw_payload).to be_nil
      end
    end

    context 'when rate limit is exhausted' do
      before do
        stub_request(:get, actor_url)
          .to_return(
            status: 200,
            body: actor_detail.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'X-RateLimit-Remaining' => '0',
              'X-RateLimit-Reset' => '1741400000',
            }
          )
      end

      it 'logs a rate limit warning' do
        expect(Rails.logger).to receive(:warn).with(
          /\[EnrichmentService\].*Rate limit exhausted/
        )
        allow(Rails.logger).to receive(:info)
        described_class.enrich(push_event)
      end

      it 'still stores the response payload' do
        allow(Rails.logger).to receive(:warn)
        described_class.enrich(push_event)
        expect(actor.reload.raw_payload).to eq(actor_detail)
      end
    end

    context 'when the repository API call fails' do
      before do
        stub_request(:get, repo_url).to_return(status: 500, body: 'Internal Server Error')
      end

      it 'logs the error and does not crash' do
        expect(Rails.logger).to receive(:error).with(
          /\[EnrichmentService\].*Failed to enrich repository/
        )
        allow(Rails.logger).to receive(:info)
        expect { described_class.enrich(push_event) }.not_to raise_error
      end

      it 'still enriches the actor' do
        allow(Rails.logger).to receive(:error)
        described_class.enrich(push_event)
        expect(actor.reload.raw_payload).to eq(actor_detail)
      end
    end

    context 'when saving the payload fails' do
      before do
        errors = double(full_messages: ['Raw payload is invalid'])
        allow(actor).to receive_messages(update: false, errors: errors)
      end

      it 'logs the save failure' do
        expect(Rails.logger).to receive(:error).with(
          /\[EnrichmentService\].*Failed to save actor.*Raw payload is invalid/
        )
        allow(Rails.logger).to receive(:info)
        described_class.enrich(push_event)
      end

      it 'does not crash and still enriches the repository' do
        allow(Rails.logger).to receive(:error)
        expect { described_class.enrich(push_event) }.not_to raise_error
        expect(repository.reload.raw_payload).to eq(repo_detail)
      end
    end
  end
end
