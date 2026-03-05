module GithubEventParser
  def self.is_push_event?(event)
    event['type'] == 'PushEvent'
  end

  def self.extract_repo_name(event)
    event.dig('repo', 'name') || 'unknown'
  end

  def self.extract_actor_login(event)
    event.dig('actor', 'login') || 'unknown'
  end

  def self.extract_push_ref(event)
    event.dig('payload', 'ref') || 'unknown'
  end
end
