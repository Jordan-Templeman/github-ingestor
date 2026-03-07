class AvatarDownloadService
  MAX_AVATAR_SIZE = 1_048_576
  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  DOWNLOAD_TIMEOUT = 5

  class << self
    def download(actor)
      return if actor.avatar_url.blank?

      if actor.avatar.attached?
        Rails.logger.info("[AvatarDownloadService] Skipped avatar for #{actor.login} (already attached)")
        return
      end

      response = fetch_avatar(actor)
      return unless response

      attach_avatar(actor, response)
    rescue StandardError => e
      Rails.logger.error("[AvatarDownloadService] Failed to download avatar for #{actor.login}: #{e.message}")
    end

    private

    def fetch_avatar(actor)
      response = HTTParty.get(actor.avatar_url, timeout: DOWNLOAD_TIMEOUT)

      unless response.success?
        Rails.logger.error(
          "[AvatarDownloadService] Failed to download avatar for #{actor.login}: HTTP #{response.code}"
        )
        return nil
      end

      response
    end

    def attach_avatar(actor, response)
      content_type = response.headers['Content-Type']&.split(';')&.first
      return reject_content_type(actor, content_type) unless ALLOWED_CONTENT_TYPES.include?(content_type)

      body = response.body
      return reject_oversized(actor, body) if body.bytesize > MAX_AVATAR_SIZE

      extension = Rack::Mime::MIME_TYPES.invert[content_type] || '.png'
      actor.avatar.attach(io: StringIO.new(body), filename: "#{actor.login}#{extension}", content_type: content_type)
      Rails.logger.info("[AvatarDownloadService] Downloaded avatar for #{actor.login}")
    end

    def reject_content_type(actor, content_type)
      Rails.logger.warn(
        "[AvatarDownloadService] Rejected avatar for #{actor.login}: content_type=#{content_type}"
      )
    end

    def reject_oversized(actor, body)
      Rails.logger.warn(
        "[AvatarDownloadService] Rejected avatar for #{actor.login}: exceeds size limit " \
        "(#{body.bytesize} bytes)"
      )
    end
  end
end
