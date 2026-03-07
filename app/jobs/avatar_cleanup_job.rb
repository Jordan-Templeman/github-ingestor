class AvatarCleanupJob
  include Sidekiq::Job

  sidekiq_options queue: 'default', retry: 3

  RETENTION_PERIOD = 7.days

  def perform
    cutoff = RETENTION_PERIOD.ago
    purged = 0

    ActiveStorage::Attachment.where(name: 'avatar').where(created_at: ...cutoff).find_each do |attachment|
      attachment.purge
      purged += 1
    end

    Rails.logger.info("[AvatarCleanupJob] Purged #{purged} avatar(s) older than #{RETENTION_PERIOD.inspect}")
  rescue StandardError => e
    Rails.logger.error("[AvatarCleanupJob] Failed: #{e.message}")
    raise
  end
end
