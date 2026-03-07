class IngestionService
  class << self
    def run
      events = GithubEventsClient.fetch
      push_events = events.select { |e| GithubEventParser.push_event?(e) }
      persisted, skipped = ingest_push_events(push_events)
      log_summary(events.size, push_events.size, persisted, skipped)
    end

    private

    def ingest_push_events(push_events)
      persisted = 0
      skipped = 0

      push_events.each do |event|
        if PushEvent.exists?(github_id: event['id'])
          skipped += 1
          next
        end

        actor = find_or_create_actor(event)
        repository = find_or_create_repository(event)
        persist_push_event(event, actor, repository)
        persisted += 1
      end

      [persisted, skipped]
    end

    def log_summary(fetched, push_count, persisted, skipped)
      Rails.logger.info(
        "[IngestionService] fetched=#{fetched} push_events=#{push_count} " \
        "persisted=#{persisted} skipped=#{skipped}"
      )
    end

    def find_or_create_actor(event)
      actor_data = event['actor']
      Actor.find_or_create_by!(github_id: actor_data['id']) do |actor|
        actor.login         = actor_data['login']
        actor.display_login = actor_data['display_login']
        actor.avatar_url    = actor_data['avatar_url']
        actor.url           = actor_data['url']
      end
    end

    def find_or_create_repository(event)
      repo_data = event['repo']
      Repository.find_or_create_by!(github_id: repo_data['id']) do |repo|
        repo.name = repo_data['name']
        repo.url  = repo_data['url']
      end
    end

    def persist_push_event(event, actor, repository)
      payload = event['payload']
      PushEvent.create!(
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
