class EnrichmentService
  class << self
    def enrich(push_event)
      safe_enrich_record(push_event.actor, label: "actor login=#{push_event.actor.login}")
      safe_enrich_record(push_event.repository, label: "repository name=#{push_event.repository.name}")
    end

    private

    def safe_enrich_record(record, label:)
      enrich_record(record, label: label)
    rescue StandardError => e
      Rails.logger.error("[EnrichmentService] Failed to enrich #{label}: #{e.message}")
    end

    def enrich_record(record, label:)
      if record.raw_payload.present?
        Rails.logger.info("[EnrichmentService] Skipped #{label} (already enriched)")
        return
      end

      response = fetch_details(record.url, label)
      return unless response

      save_payload(record, response.parsed_response, label)
    end

    def fetch_details(url, label)
      unless GithubApiConfig.allowed_url?(url)
        Rails.logger.error("[EnrichmentService] Blocked non-GitHub URL for #{label}: #{url}")
        return nil
      end

      response = HTTParty.get(url, headers: GithubApiConfig::HEADERS, timeout: GithubApiConfig::TIMEOUT)

      log_rate_limit(response)

      unless response.success?
        Rails.logger.error("[EnrichmentService] Failed to enrich #{label}: #{response.code}")
        return nil
      end

      response
    end

    def log_rate_limit(response)
      remaining = response.headers['X-RateLimit-Remaining']
      return if remaining.nil?
      return unless remaining.to_i.zero?

      reset_header = response.headers['X-RateLimit-Reset']
      reset_at = reset_header ? Time.at(reset_header.to_i).utc.iso8601 : 'unknown'
      Rails.logger.warn(
        "[EnrichmentService] Rate limit exhausted — resets at #{reset_at}"
      )
    end

    def save_payload(record, payload, label)
      if record.update(raw_payload: payload)
        Rails.logger.info("[EnrichmentService] Enriched #{label}")
      else
        Rails.logger.error(
          "[EnrichmentService] Failed to save #{label}: " \
          "#{record.errors.full_messages.join(', ')}"
        )
      end
    end
  end
end
