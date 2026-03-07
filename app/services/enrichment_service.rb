class EnrichmentService
  class << self
    def enrich_batch(push_events)
      return if push_events.empty?

      actors = push_events.map(&:actor).uniq(&:id)
      repositories = push_events.map(&:repository).uniq(&:id)

      remaining_budget = fetch_rate_limit_budget

      remaining_budget = enrich_records(actors, 'actor', remaining_budget)
      actors.each { |actor| safe_download_avatar(actor) }
      enrich_records(repositories, 'repository', remaining_budget)
    end

    def enrich(push_event)
      enrich_batch([push_event])
    end

    private

    def fetch_rate_limit_budget
      url = "#{GithubApiConfig::BASE_URL}/rate_limit"
      response = HTTParty.get(url, headers: GithubApiConfig::HEADERS, timeout: GithubApiConfig::TIMEOUT)
      remaining = response.headers['X-RateLimit-Remaining']
      remaining&.to_i
    rescue StandardError => e
      Rails.logger.warn("[EnrichmentService] Could not fetch rate limit budget: #{e.message}")
      nil
    end

    def enrich_records(records, type, remaining_budget)
      records.each do |record|
        label = build_label(record, type)

        if remaining_budget && remaining_budget <= 0
          Rails.logger.warn("[EnrichmentService] Rate limit budget exhausted, skipping #{label}")
          next
        end

        safe_enrich_record(record, label: label)
        remaining_budget -= 1 if remaining_budget
      end

      remaining_budget
    end

    def build_label(record, type)
      identifier = type == 'actor' ? "login=#{record.login}" : "name=#{record.name}"
      "#{type} #{identifier}"
    end

    def safe_enrich_record(record, label:)
      enrich_record(record, label: label)
    rescue StandardError => e
      Rails.logger.error("[EnrichmentService] Failed to enrich #{label}: #{e.message}")
    end

    def safe_download_avatar(actor)
      AvatarDownloadService.download(actor)
    rescue StandardError => e
      Rails.logger.error("[EnrichmentService] Failed to download avatar for #{actor.login}: #{e.message}")
    end

    def enrich_record(record, label:)
      response = fetch_details(record, label)
      return unless response

      if response.code == 304
        Rails.logger.info("[EnrichmentService] Skipped #{label} (ETag matched, not modified)")
        return
      end

      save_payload(record, response, label)
    end

    def fetch_details(record, label)
      unless GithubApiConfig.allowed_url?(record.url)
        Rails.logger.error("[EnrichmentService] Blocked non-GitHub URL for #{label}: #{record.url}")
        return nil
      end

      headers = GithubApiConfig::HEADERS.dup
      headers['If-None-Match'] = record.etag if record.etag.present?

      response = HTTParty.get(record.url, headers: headers, timeout: GithubApiConfig::TIMEOUT)

      log_rate_limit(response)

      return response if response.code == 304

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

    def save_payload(record, response, label)
      etag = response.headers['ETag']
      attrs = { raw_payload: response.parsed_response }
      attrs[:etag] = etag if etag.present?

      if record.update(attrs)
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
