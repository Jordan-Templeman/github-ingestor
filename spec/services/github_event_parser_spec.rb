require 'spec_helper'

RSpec.describe GithubEventParser do
  describe '.is_push_event?' do
    it 'returns true for PushEvent' do
      event = { 'type' => 'PushEvent' }
      expect(GithubEventParser.is_push_event?(event)).to be true
    end

    it 'returns false for other events' do
      event = { 'type' => 'IssuesEvent' }
      expect(GithubEventParser.is_push_event?(event)).to be false
    end
  end
end
