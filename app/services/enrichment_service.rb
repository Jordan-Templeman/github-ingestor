class EnrichmentService
  class << self
    def enrich(push_event)
      enrich_record(push_event.actor, label: "actor login=#{push_event.actor.login}")
      enrich_record(push_event.repository, label: "repository name=#{push_event.repository.name}")
    end

    private

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
      response = HTTParty.get(url, headers: GithubApiConfig::HEADERS)

      unless response.success?
        Rails.logger.error("[EnrichmentService] Failed to enrich #{label}: #{response.code}")
        return nil
      end

      response
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
