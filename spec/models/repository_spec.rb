require 'rails_helper'

RSpec.describe Repository, type: :model do
  describe 'validations' do
    subject { build(:repository) }

    it { should validate_presence_of(:github_id) }
    it { should validate_uniqueness_of(:github_id) }
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should have_many(:push_events).dependent(:destroy) }
  end
end
