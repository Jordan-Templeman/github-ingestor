require 'rails_helper'

RSpec.describe EnrichmentService do
  let(:actor_url)  { 'https://api.github.com/users/octocat' }
  let(:repo_url)   { 'https://api.github.com/repos/octocat/hello-world' }
  let(:rate_limit_url) { 'https://api.github.com/rate_limit' }

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
    stub_request(:get, rate_limit_url)
      .to_return(
        status: 200,
        body: '{}',
        headers: { 'X-RateLimit-Remaining' => '100' }
      )

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

    context 'when actor has a cached ETag' do
      let(:actor) do
        create(:actor, login: 'octocat', url: actor_url, raw_payload: { 'cached' => true }, etag: '"abc123"')
      end

      before do
        stub_request(:get, actor_url)
          .with(headers: GithubApiConfig::HEADERS.merge('If-None-Match' => '"abc123"'))
          .to_return(status: 304, body: '', headers: {})
      end

      it 'sends If-None-Match header and skips update on 304' do
        described_class.enrich(push_event)
        expect(actor.reload.raw_payload).to eq({ 'cached' => true })
      end

      it 'logs the ETag skip' do
        expect(Rails.logger).to receive(:info).with(
          /\[EnrichmentService\].*Skipped actor.*not modified/
        )
        allow(Rails.logger).to receive(:info)
        described_class.enrich(push_event)
      end
    end

    context 'when repository has a cached ETag' do
      let(:repository) do
        create(:repository, name: 'octocat/hello-world', url: repo_url,
                            raw_payload: { 'cached' => true }, etag: '"repo456"')
      end

      before do
        stub_request(:get, repo_url)
          .with(headers: GithubApiConfig::HEADERS.merge('If-None-Match' => '"repo456"'))
          .to_return(status: 304, body: '', headers: {})
      end

      it 'sends If-None-Match header and skips update on 304' do
        described_class.enrich(push_event)
        expect(repository.reload.raw_payload).to eq({ 'cached' => true })
      end

      it 'logs the ETag skip' do
        expect(Rails.logger).to receive(:info).with(
          /\[EnrichmentService\].*Skipped repository.*not modified/
        )
        allow(Rails.logger).to receive(:info)
        described_class.enrich(push_event)
      end
    end

    context 'when the response includes an ETag header' do
      before do
        stub_request(:get, actor_url)
          .to_return(
            status: 200,
            body: actor_detail.to_json,
            headers: { 'Content-Type' => 'application/json', 'ETag' => '"new-etag"' }
          )
      end

      it 'stores the ETag on the record' do
        described_class.enrich(push_event)
        expect(actor.reload.etag).to eq('"new-etag"')
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

    context 'when rate limit budget is zero from the start' do
      before do
        stub_request(:get, rate_limit_url)
          .to_return(
            status: 200,
            body: '{}',
            headers: { 'X-RateLimit-Remaining' => '0' }
          )
      end

      it 'skips all enrichment and logs warnings' do
        expect(Rails.logger).to receive(:warn).with(
          /\[EnrichmentService\].*Rate limit budget exhausted.*actor/
        ).at_least(:once)
        allow(Rails.logger).to receive(:warn)
        described_class.enrich(push_event)
        expect(actor.reload.raw_payload).to be_nil
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

  describe '.enrich_batch' do
    it 'deduplicates actors across multiple push events' do
      second_event = create(:push_event, actor: actor, repository: create(:repository, url: 'https://api.github.com/repos/other/repo'))

      stub_request(:get, 'https://api.github.com/repos/other/repo')
        .to_return(status: 200, body: repo_detail.to_json, headers: { 'Content-Type' => 'application/json' })

      described_class.enrich_batch([push_event, second_event])
      expect(a_request(:get, actor_url)).to have_been_made.once
    end

    it 'handles empty array without error' do
      expect { described_class.enrich_batch([]) }.not_to raise_error
    end
  end
end
