require 'spec_helper'

RSpec.describe GithubEventParser do
  describe '.push_event?' do
    it 'returns true for PushEvent' do
      event = { 'type' => 'PushEvent' }
      expect(described_class.push_event?(event)).to be true
    end

    it 'returns false for other events' do
      event = { 'type' => 'IssuesEvent' }
      expect(described_class.push_event?(event)).to be false
    end
  end
end
