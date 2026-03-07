module GithubEventParser
  def self.push_event?(event)
    event['type'] == 'PushEvent'
  end
end
