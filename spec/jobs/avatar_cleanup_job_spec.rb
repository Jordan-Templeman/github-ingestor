require 'rails_helper'

RSpec.describe AvatarCleanupJob do
  describe 'sidekiq options' do
    it 'uses the default queue' do
      expect(described_class.sidekiq_options['queue']).to eq('default')
    end

    it 'retries up to 3 times' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end

  describe '#perform' do
    let(:image_body) { Rails.root.join('spec/fixtures/files/avatar.png').binread }

    it 'purges avatars older than the retention period' do
      actor = create(:actor)
      actor.avatar.attach(io: StringIO.new(image_body), filename: 'old.png', content_type: 'image/png')

      Timecop.travel(8.days.from_now) do
        described_class.new.perform
      end

      expect(actor.reload.avatar).not_to be_attached
    end

    it 'keeps avatars within the retention period' do
      actor = create(:actor)
      actor.avatar.attach(io: StringIO.new(image_body), filename: 'recent.png', content_type: 'image/png')

      described_class.new.perform

      expect(actor.reload.avatar).to be_attached
    end

    it 'handles actors with no avatar attached' do
      create(:actor)

      expect { described_class.new.perform }.not_to raise_error
    end

    it 'logs the cleanup summary' do
      actor = create(:actor)
      actor.avatar.attach(io: StringIO.new(image_body), filename: 'old.png', content_type: 'image/png')
      allow(Rails.logger).to receive(:info)

      Timecop.travel(8.days.from_now) do
        described_class.new.perform
      end

      expect(Rails.logger).to have_received(:info).with(/Purged.*avatar/)
    end
  end
end
