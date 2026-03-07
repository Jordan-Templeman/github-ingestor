class IngestionJob
  include Sidekiq::Job

  # Retries with Sidekiq's built-in exponential backoff:
  # delay = retry_count**4 + 15 (approx 16s, 31s, 96s)
  sidekiq_options queue: 'default', retry: 3

  sidekiq_retries_exhausted do |msg, _exception|
    Rails.logger.error(
      "[IngestionJob] Retries exhausted after #{msg['retry_count']} attempts: #{msg['error_message']}"
    )
  end

  def perform
    Rails.logger.info('[IngestionJob] Starting ingestion')
    IngestionService.run
    Rails.logger.info('[IngestionJob] Completed ingestion')
  rescue StandardError => e
    Rails.logger.error("[IngestionJob] Failed: #{e.message}")
    raise
  end
end
