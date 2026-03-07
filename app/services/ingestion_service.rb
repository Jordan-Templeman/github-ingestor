class IngestionService
  class << self
    def run
      events = GithubEventsClient.fetch
      push_events = events.select { |e| GithubEventParser.push_event?(e) }
      persisted_events, skipped, errored = ingest_push_events(push_events)
      safe_enrich_batch(persisted_events)
      log_summary(events.size, push_events.size, persisted_events.size, skipped, errored)
    end

    private

    def ingest_push_events(push_events)
      persisted_events = []
      counts = { skipped: 0, errored: 0 }

      push_events.each do |event|
        result = ingest_one(event, counts)
        persisted_events << result if result
      end

      [persisted_events, counts[:skipped], counts[:errored]]
    end

    def ingest_one(event, counts)
      if PushEvent.exists?(github_id: event['id'])
        counts[:skipped] += 1
        return nil
      end

      push_event = create_push_event(event)
      record_result(push_event, event, counts)
    rescue StandardError => e
      counts[:errored] += 1
      log_error(event, e.message)
      nil
    end

    def create_push_event(event)
      actor = find_or_create_actor(event)
      repository = find_or_create_repository(event)
      persist_push_event(event, actor, repository)
    end

    def record_result(push_event, event, counts)
      if push_event.persisted?
        push_event
      else
        counts[:errored] += 1
        log_error(event, push_event.errors.full_messages.join(', '))
        nil
      end
    end

    def safe_enrich_batch(push_events)
      EnrichmentService.enrich_batch(push_events)
    rescue StandardError => e
      Rails.logger.error("[IngestionService] Batch enrichment failed: #{e.message}")
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
