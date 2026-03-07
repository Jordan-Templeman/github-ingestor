require 'rails_helper'

RSpec.describe IngestionJob do
  describe '.sidekiq_options' do
    it 'retries up to 3 times' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end

    it 'uses the default queue' do
      expect(described_class.sidekiq_options['queue']).to eq('default')
    end
  end

  describe '#perform' do
    it 'delegates to IngestionService.run' do
      expect(IngestionService).to receive(:run)
      described_class.new.perform
    end

    it 'logs before and after ingestion' do
      allow(IngestionService).to receive(:run)
      expect(Rails.logger).to receive(:info).with(/\[IngestionJob\].*Starting/)
      expect(Rails.logger).to receive(:info).with(/\[IngestionJob\].*Completed/)
      described_class.new.perform
    end

    context 'when IngestionService raises an error' do
      before do
        allow(IngestionService).to receive(:run).and_raise(StandardError, 'connection refused')
      end

      it 'logs the error and re-raises for Sidekiq retry' do
        expect(Rails.logger).to receive(:error).with(
          /\[IngestionJob\].*Failed.*connection refused/
        )
        expect { described_class.new.perform }.to raise_error(StandardError, 'connection refused')
      end
    end
  end
end
