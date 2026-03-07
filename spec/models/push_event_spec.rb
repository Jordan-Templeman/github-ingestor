require 'rails_helper'

RSpec.describe PushEvent, type: :model do
  describe 'validations' do
    subject { build(:push_event) }

    it { should validate_presence_of(:github_id) }
    it { should validate_uniqueness_of(:github_id) }
    it { should validate_presence_of(:ref) }
    it { should validate_presence_of(:head) }
    it { should validate_presence_of(:before) }
    it { should validate_presence_of(:raw_payload) }
  end

  describe 'associations' do
    it { should belong_to(:actor) }
    it { should belong_to(:repository) }
  end
end
