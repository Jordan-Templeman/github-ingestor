require 'uri'

module GithubApiConfig
  HEADERS = {
    'Accept' => 'application/vnd.github+json',
    'User-Agent' => 'StrongMind-GitHub-Ingestor',
  }.freeze

  BASE_URL = ENV.fetch('GITHUB_API_URL', 'https://api.github.com')

  TIMEOUT = 10

  ALLOWED_HOST = URI.parse(BASE_URL).host.freeze

  def self.allowed_url?(url)
    uri = URI.parse(url.to_s)
    uri.scheme == 'https' && uri.host == ALLOWED_HOST && uri.path.present?
  rescue URI::InvalidURIError
    false
  end
end
