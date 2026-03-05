# StrongMind GitHub Ingestor — Implementation Plan

## Current State

Foundation is in place:
- Rails 7.1 API app, PostgreSQL, Docker Compose
- `GithubEventParser` service + passing spec
- `DESIGN.md`, `Dockerfile`, Gemfile with httparty / jsonapi-serializer / rspec stack
- Sidekiq/Redis present but unused — removed before first commit

---

## Approach: TDD Throughout

Every phase follows **red → green**:
1. Write the spec(s) first — they fail
2. Write the minimum implementation to make them pass
3. Refactor if needed
4. Commit

---

## Phase 0 — Cleanup & Documentation (pre-first-commit)

**Gemfile:**
- Remove commented `sidekiq` and `redis` gems

**docker-compose.yml:**
- Remove `redis` and `sidekiq` services
- Remove `REDIS_URL` env vars from all remaining services
- Final services: `db`, `app`, `ingest`, `test`

**DESIGN.md** — rewrite to match actual architecture:
- No Sidekiq/Redis; enrichment is inline
- Rate limit strategy via response headers
- Idempotency via `find_or_create_by` + skip-if-exists
- Data model summary (actors, repositories, push_events)
- What was intentionally not built

**README.md** — full rewrite:
- Project overview
- `docker compose up --build` — start the system
- `docker compose run --rm ingest` — run ingestion
- `docker compose run --rm test` — run tests
- "How to verify it's working" section:
  - Expected log lines
  - Which DB tables to query and what to look for
  - How long before results appear

Then `/smart-commit` the cleaned-up foundation.

---

## Phase 1 — Data Models & Migrations

**Test first:**
- `spec/models/actor_spec.rb` — validations, uniqueness of `github_id`
- `spec/models/repository_spec.rb` — validations, uniqueness of `github_id`
- `spec/models/push_event_spec.rb` — validations, uniqueness of `github_id`, associations

**Then implement:**
- `db/migrate/..._create_actors.rb`
- `db/migrate/..._create_repositories.rb`
- `db/migrate/..._create_push_events.rb`
- `app/models/actor.rb`, `repository.rb`, `push_event.rb`

**Schema:**

```
actors
  github_id      bigint  NOT NULL UNIQUE
  login          string  NOT NULL
  display_login  string
  avatar_url     string
  url            string
  raw_payload    jsonb
  timestamps

repositories
  github_id    bigint  NOT NULL UNIQUE
  name         string  NOT NULL
  full_name    string
  url          string
  raw_payload  jsonb
  timestamps

push_events
  github_id      string  NOT NULL UNIQUE   # event["id"]
  actor_id       bigint  FK → actors
  repository_id  bigint  FK → repositories
  ref            string  NOT NULL
  head           string  NOT NULL
  before         string  NOT NULL
  push_id        bigint
  raw_payload    jsonb   NOT NULL
  timestamps
```

---

## Phase 2 — GitHub Events Client

**Test first:** `spec/services/github_events_client_spec.rb`
- Stubs HTTParty via WebMock
- Returns parsed event array on 200
- Raises `RateLimitedError` when `X-RateLimit-Remaining: 0`
- Handles 429 with `Retry-After`
- Logs request url, status, rate_limit_remaining

**Then implement:** `app/services/github_events_client.rb`

```ruby
GithubEventsClient.fetch          # GET /events → Array of hashes
GithubEventsClient::RateLimitedError
```

---

## Phase 3 — Ingestion Service

**Test first:** `spec/services/ingestion_service_spec.rb`
- Uses fixture JSON (real-shaped GitHub events payload)
- Persists new PushEvents
- Skips duplicates on re-run (idempotent)
- Creates Actor + Repository records
- Logs fetched / filtered / skipped / persisted counts

**Then implement:** `app/services/ingestion_service.rb`

```
IngestionService.run:
  1. GithubEventsClient.fetch
  2. Filter to PushEvents via GithubEventParser
  3. Per event:
     a. Skip if PushEvent already exists (github_id)
     b. find_or_create_by Actor (github_id)
     c. find_or_create_by Repository (github_id)
     d. Persist PushEvent with raw_payload
     e. EnrichmentService.enrich(push_event)
  4. Log summary
```

---

## Phase 4 — Enrichment Service (Inline)

**Test first:** `spec/services/enrichment_service_spec.rb`
- Fetches actor URL if `raw_payload` is nil → updates record
- Skips actor if `raw_payload` already present
- Fetches repo URL if `raw_payload` is nil → updates record
- Skips repo if `raw_payload` already present

**Then implement:** `app/services/enrichment_service.rb`

```
EnrichmentService.enrich(push_event):
  - Skip if actor.raw_payload.present?  → GET actor.url → update
  - Skip if repository.raw_payload.present? → GET repository.url → update
```

---

## Phase 5 — Observability

Structured log lines via `Rails.logger` throughout all services:

```
[GithubClient] GET /events status=200 rate_limit_remaining=58
[GithubClient] Rate limited — resets at 2024-01-01T00:00:00Z
[Ingestion] Fetched 30 events, 4 PushEvents
[Ingestion] Persisted push_event github_id=123456
[Ingestion] Skipped duplicate github_id=789
[Enrichment] Fetching actor url=https://api.github.com/users/foo
[Enrichment] Skipped actor login=foo (already enriched)
```

Malformed payloads rescued per-event: log error + skip, no crash-loop.

---

## Phase 6 — JSON:API Layer

**Test first:** request specs for each resource
- `spec/requests/api/v1/push_events_spec.rb`
- `spec/requests/api/v1/actors_spec.rb`
- `spec/requests/api/v1/repositories_spec.rb`

Each covers: index (JSON:API format, limit/offset pagination), show, 404 on missing.

**Then implement:**
- `app/controllers/api/v1/push_events_controller.rb` — index, show
- `app/controllers/api/v1/actors_controller.rb` — index, show
- `app/controllers/api/v1/repositories_controller.rb` — index, show
- `app/serializers/push_event_serializer.rb`
- `app/serializers/actor_serializer.rb`
- `app/serializers/repository_serializer.rb`
- `config/routes.rb` — namespace :api > :v1 > resources

---

## Phase 7 — Postman Collection

- `postman/github_ingestor.postman_collection.json`
- `postman/github_ingestor.postman_environment.json` (`base_url = http://localhost:3000`)
- Folders: PushEvents / Actors / Repositories — index + show per resource
- README updated with import instructions

---

## Extensions Addressed

| Extension | Approach |
|-----------|----------|
| A — Rate Limiting | `GithubEventsClient` reads headers, raises `RateLimitedError`, logs state |
| B — Idempotency | `find_or_create_by` + skip-if-exists guard in ingestion |
| D — Testing | RSpec unit + request specs, WebMock for HTTP, FactoryBot for fixtures |

Extension C (object storage) intentionally out of scope.
