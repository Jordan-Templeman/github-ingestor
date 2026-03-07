require 'rails_helper'

RSpec.describe PushEvent, type: :model do
  describe 'validations' do
    subject { build(:push_event) }

    it { is_expected.to validate_presence_of(:github_id) }
    it { is_expected.to validate_uniqueness_of(:github_id) }
    it { is_expected.to validate_presence_of(:ref) }
    it { is_expected.to validate_presence_of(:head) }
    it { is_expected.to validate_presence_of(:before) }
    it { is_expected.to validate_presence_of(:raw_payload) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:actor) }
    it { is_expected.to belong_to(:repository) }
  end
end
