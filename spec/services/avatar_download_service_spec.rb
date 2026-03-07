require 'rails_helper'

RSpec.describe AvatarDownloadService do
  describe '.download' do
    let(:actor) { create(:actor, avatar_url: 'https://avatars.githubusercontent.com/u/12345?v=4') }
    let(:image_body) { Rails.root.join('spec/fixtures/files/avatar.png').binread }

    before do
      stub_request(:get, actor.avatar_url)
        .to_return(status: 200, body: image_body, headers: { 'Content-Type' => 'image/png' })
    end

    it 'downloads and attaches avatar when not already attached' do
      described_class.download(actor)

      expect(actor.avatar).to be_attached
    end

    it 'sets the filename based on actor login' do
      described_class.download(actor)

      expect(actor.avatar.filename.to_s).to eq("#{actor.login}.png")
    end

    it 'skips download when avatar is already attached' do
      actor.avatar.attach(io: StringIO.new(image_body), filename: 'existing.png', content_type: 'image/png')

      described_class.download(actor)

      expect(a_request(:get, actor.avatar_url)).not_to have_been_made
    end

    it 'skips download when avatar_url is blank' do
      actor.update(avatar_url: nil)

      described_class.download(actor)

      expect(actor.avatar).not_to be_attached
    end

    it 'logs successful download' do
      allow(Rails.logger).to receive(:info)

      described_class.download(actor)

      expect(Rails.logger).to have_received(:info).with(/Downloaded avatar.*#{actor.login}/)
    end

    it 'logs skip when already attached' do
      actor.avatar.attach(io: StringIO.new(image_body), filename: 'existing.png', content_type: 'image/png')
      allow(Rails.logger).to receive(:info)

      described_class.download(actor)

      expect(Rails.logger).to have_received(:info).with(/Skipped avatar.*#{actor.login}/)
    end

    context 'when download fails with HTTP error' do
      before do
        stub_request(:get, actor.avatar_url).to_return(status: 404)
      end

      it 'does not attach avatar' do
        described_class.download(actor)

        expect(actor.avatar).not_to be_attached
      end

      it 'logs the failure' do
        allow(Rails.logger).to receive(:error)

        described_class.download(actor)

        expect(Rails.logger).to have_received(:error).with(/Failed to download avatar.*#{actor.login}/)
      end
    end

    context 'when download fails with network error' do
      before do
        stub_request(:get, actor.avatar_url).to_timeout
      end

      it 'does not attach avatar' do
        described_class.download(actor)

        expect(actor.avatar).not_to be_attached
      end

      it 'logs the failure' do
        allow(Rails.logger).to receive(:error)

        described_class.download(actor)

        expect(Rails.logger).to have_received(:error).with(/Failed to download avatar.*#{actor.login}/)
      end
    end

    context 'when response content type is not an image' do
      before do
        stub_request(:get, actor.avatar_url)
          .to_return(status: 200, body: '<html>not an image</html>', headers: { 'Content-Type' => 'text/html' })
      end

      it 'does not attach avatar' do
        described_class.download(actor)

        expect(actor.avatar).not_to be_attached
      end

      it 'logs the rejection' do
        allow(Rails.logger).to receive(:warn)

        described_class.download(actor)

        expect(Rails.logger).to have_received(:warn).with(%r{Rejected avatar.*content_type=text/html})
      end
    end

    context 'when response body exceeds size limit' do
      before do
        large_body = 'x' * (described_class::MAX_AVATAR_SIZE + 1)
        stub_request(:get, actor.avatar_url)
          .to_return(status: 200, body: large_body, headers: { 'Content-Type' => 'image/png' })
      end

      it 'does not attach avatar' do
        described_class.download(actor)

        expect(actor.avatar).not_to be_attached
      end

      it 'logs the rejection' do
        allow(Rails.logger).to receive(:warn)

        described_class.download(actor)

        expect(Rails.logger).to have_received(:warn).with(/Rejected avatar.*exceeds size limit/)
      end
    end
  end
end
