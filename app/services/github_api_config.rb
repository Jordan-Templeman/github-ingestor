module GithubApiConfig
  HEADERS = {
    'Accept' => 'application/vnd.github+json',
    'User-Agent' => 'StrongMind-GitHub-Ingestor',
  }.freeze

  BASE_URL = ENV.fetch('GITHUB_API_URL', 'https://api.github.com')
end
