# Design Brief — GitHub Ingestor

## Problem Understanding

StrongMind needs visibility into GitHub activity to analyze repository usage and contributor behavior over time. This service ingests GitHub Push events from the public GitHub Events API, enriches them with actor and repository data, and stores everything in PostgreSQL for future querying and analysis.

## Architecture

### Components

- **Rails 7.1 API-only app** — orchestrates ingestion, enrichment, and serves a JSON:API query layer
- **PostgreSQL** — system of record for raw and structured event data
- **GithubEventsClient** — handles all GitHub API requests, reads rate limit headers, raises on exhaustion
- **IngestionService** — fetch → filter → persist pipeline, runs on-demand via `docker compose run --rm ingest`
- **EnrichmentService** — inline enrichment after each event is saved; fetches actor and repository detail URLs from the event payload

### Data Model

```
actors
  github_id, login, display_login, avatar_url, url, raw_payload

repositories
  github_id, name, full_name, url, raw_payload

push_events
  github_id, ref, head, before, push_id
  actor_id (FK), repository_id (FK)
  raw_payload
```

Raw payloads are stored on all three tables for audit and debug purposes. Structured fields on `push_events` (ref, head, before, push_id, repository identifier) are queryable without JSON parsing.

## Key Tradeoffs and Assumptions

- **Rails over Sinatra**: Active Record migrations, associations, and the test ecosystem (RSpec, FactoryBot, shoulda-matchers) justify the overhead for a service that will grow.
- **Inline enrichment over background jobs**: Removes Redis/Sidekiq as runtime dependencies, making the system simpler to operate. The tradeoff is that ingestion runs are slightly slower when new actors or repos are encountered. Given the rate limit budget (60 req/hour unauthenticated), background processing would not meaningfully increase throughput.
- **No authentication token**: Per requirements. The system is designed to stay within the 60 req/hour unauthenticated limit through header-aware rate limiting and skip-if-already-enriched logic.
- **On-demand ingestion**: `IngestionService.run` is invoked explicitly. Continuous polling is not implemented — the operator decides when to ingest.

## Rate Limiting

GitHub's unauthenticated API allows 60 requests/hour. The client:
- Reads `X-RateLimit-Remaining` and `X-RateLimit-Reset` on every response
- Logs the remaining budget after each request
- Raises `GithubEventsClient::RateLimitedError` when remaining hits 0, with the reset timestamp logged
- Handles 429 responses with `Retry-After`

Enrichment skips actors and repositories whose `raw_payload` is already populated, preventing redundant API calls on repeated ingestion runs.

## Idempotency and Restart Safety

- `PushEvent` records are skipped if `github_id` already exists — re-running ingestion is safe
- `Actor` and `Repository` use `find_or_create_by(github_id:)` — no duplicates created
- Enrichment checks `raw_payload.present?` before fetching — no redundant network calls

## Observability

All services log structured lines to stdout via `Rails.logger`:

```
[GithubClient] GET /events status=200 rate_limit_remaining=58
[Ingestion] Fetched 30 events, 4 PushEvents
[Ingestion] Persisted push_event github_id=123456
[Ingestion] Skipped duplicate github_id=789
[Enrichment] Fetching actor url=https://api.github.com/users/foo
[Enrichment] Skipped actor login=foo (already enriched)
```

Malformed or unexpected payloads are rescued per-event: the error is logged with context and processing continues. The service does not crash-loop on transient failures.

## What Was Intentionally Not Built

- **Sidekiq / Redis** — not needed given inline enrichment and on-demand ingestion model
- **Continuous polling** — out of scope; ingestion is operator-triggered
- **Web UI** — API-only
- **User authentication** — internal service, no auth layer
- **Object storage** (Extension C) — avatars and raw blobs are stored in PostgreSQL jsonb columns
- **Advanced analytics / reporting** — the JSON:API layer supports basic querying; dashboards are out of scope
