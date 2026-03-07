require 'rails_helper'

RSpec.describe Repository, type: :model do
  describe 'validations' do
    subject { build(:repository) }

    it { is_expected.to validate_presence_of(:github_id) }
    it { is_expected.to validate_uniqueness_of(:github_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:push_events).dependent(:destroy) }
  end
end
