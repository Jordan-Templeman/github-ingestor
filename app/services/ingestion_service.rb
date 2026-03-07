class IngestionService
  class << self
    def run
      events = GithubEventsClient.fetch
      push_events = events.select { |e| GithubEventParser.push_event?(e) }
      persisted, skipped, errored = ingest_push_events(push_events)
      log_summary(events.size, push_events.size, persisted, skipped, errored)
    end

    private

    # Processes events individually so one malformed or invalid event
    # does not block the rest of the batch. Trade-off: individual
    # writes per event rather than a batch upsert. Validations still
    # run on every record. Acceptable at GitHub's public API scale
    # (30 events/page) but would benefit from bulk inserts if volume
    # grows significantly.
    def ingest_push_events(push_events)
      counts = { persisted: 0, skipped: 0, errored: 0 }

      push_events.each do |event|
        ingest_one(event, counts)
      end

      counts.values_at(:persisted, :skipped, :errored)
    end

    def ingest_one(event, counts)
      if PushEvent.exists?(github_id: event['id'])
        counts[:skipped] += 1
        return
      end

      actor = find_or_create_actor(event)
      repository = find_or_create_repository(event)
      push_event = persist_push_event(event, actor, repository)
      record_result(push_event, event, counts)
      safe_enrich(push_event) if push_event.persisted?
    rescue StandardError => e
      counts[:errored] += 1
      log_error(event, e.message)
    end

    def record_result(push_event, event, counts)
      if push_event.persisted?
        counts[:persisted] += 1
      else
        counts[:errored] += 1
        log_error(event, push_event.errors.full_messages.join(', '))
      end
    end

    def safe_enrich(push_event)
      EnrichmentService.enrich(push_event)
    rescue StandardError => e
      Rails.logger.error(
        "[IngestionService] Enrichment failed for event id=#{push_event.github_id}: #{e.message}"
      )
    end

    def log_error(event, message)
      Rails.logger.error(
        "[IngestionService] Failed to ingest event id=#{event['id']}: #{message}"
      )
    end

    def log_summary(fetched, push_count, persisted, skipped, errored)
      Rails.logger.info(
        "[IngestionService] fetched=#{fetched} push_events=#{push_count} " \
        "persisted=#{persisted} skipped=#{skipped} errored=#{errored}"
      )
    end

    def find_or_create_actor(event)
      actor_data = event['actor']
      Actor.find_or_create_by(github_id: actor_data['id']) do |actor|
        actor.login         = actor_data['login']
        actor.display_login = actor_data['display_login']
        actor.avatar_url    = actor_data['avatar_url']
        actor.url           = actor_data['url']
      end
    end

    def find_or_create_repository(event)
      repo_data = event['repo']
      Repository.find_or_create_by(github_id: repo_data['id']) do |repo|
        repo.name = repo_data['name']
        repo.url  = repo_data['url']
      end
    end

    def persist_push_event(event, actor, repository)
      payload = event['payload']
      PushEvent.create(
        github_id: event['id'],
        actor: actor,
        repository: repository,
        ref: payload['ref'],
        head: payload['head'],
        before: payload['before'],
        push_id: payload['push_id'],
        raw_payload: event
      )
    end
  end
end
