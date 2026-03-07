class AvatarCleanupJob
  include Sidekiq::Job

  sidekiq_options queue: 'default', retry: 3

  sidekiq_retries_exhausted do |msg, _exception|
    Rails.logger.error(
      "[AvatarCleanupJob] Retries exhausted after #{msg['retry_count']} attempts: #{msg['error_message']}"
    )
  end

  RETENTION_PERIOD = 7.days

  def perform
    purged, errored = purge_expired_avatars
    Rails.logger.info("[AvatarCleanupJob] Purged #{purged} avatar(s), errored=#{errored}")
  rescue StandardError => e
    Rails.logger.error("[AvatarCleanupJob] Failed: #{e.message}")
    raise
  end

  private

  def purge_expired_avatars
    cutoff = RETENTION_PERIOD.ago
    purged = 0
    errored = 0

    ActiveStorage::Attachment.where(name: 'avatar').where(created_at: ...cutoff).find_each do |attachment|
      attachment.purge
      purged += 1
    rescue StandardError => e
      errored += 1
      Rails.logger.error("[AvatarCleanupJob] Failed to purge attachment id=#{attachment.id}: #{e.message}")
    end

    [purged, errored]
  end
end
