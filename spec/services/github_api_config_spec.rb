require 'rails_helper'

RSpec.describe GithubApiConfig do
  describe '.allowed_url?' do
    it 'allows URLs under the configured base URL' do
      expect(described_class.allowed_url?('https://api.github.com/users/octocat')).to be true
    end

    it 'allows nested paths under the base URL' do
      expect(described_class.allowed_url?('https://api.github.com/repos/octocat/hello-world')).to be true
    end

    it 'rejects URLs from a different host' do
      expect(described_class.allowed_url?('http://evil.example.com/users/octocat')).to be false
    end

    it 'rejects URLs that share a prefix but differ in host' do
      expect(described_class.allowed_url?('https://api.github.com.evil.com/foo')).to be false
    end

    it 'rejects the base URL itself without a trailing path' do
      expect(described_class.allowed_url?('https://api.github.com')).to be false
    end

    it 'rejects nil' do
      expect(described_class.allowed_url?(nil)).to be false
    end

    it 'rejects an empty string' do
      expect(described_class.allowed_url?('')).to be false
    end
  end
end
