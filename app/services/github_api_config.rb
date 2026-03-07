module GithubApiConfig
  HEADERS = {
    'Accept' => 'application/vnd.github+json',
    'User-Agent' => 'StrongMind-GitHub-Ingestor',
  }.freeze

  BASE_URL = ENV.fetch('GITHUB_API_URL', 'https://api.github.com')

  TIMEOUT = 10

  def self.allowed_url?(url)
    url.to_s.start_with?("#{BASE_URL}/")
  end
end
