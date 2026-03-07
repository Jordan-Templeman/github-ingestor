# Design Brief — GitHub Ingestor

## How I Approached This

The first thing I did was read the requirements carefully and resist the urge to immediately start building. The prompt explicitly says it cares more about how you think than how much you build — so I treated the planning step as real work.

I broke the problem down by asking: what is the smallest slice of working, verifiable behavior I can build first, and what does everything else depend on? That gave me a natural sequence:

1. **Data model first** — everything else (ingestion, enrichment, the API layer) writes to and reads from the database. Getting the schema right before writing service logic prevents painful refactoring later.
2. **Client before service** — the ingestion service depends on the HTTP client. Testing the client in isolation with stubbed HTTP keeps the concerns clean.
3. **Ingestion before enrichment** — persist the raw event first, enrich second. This way the core pipeline works and is testable even if enrichment has issues.
4. **Observability woven in, not bolted on** — logging decisions were made at the time each service was written, not added at the end.
5. **API layer last** — it's a read layer over data that already exists. Building it last meant the serializers and controllers had real data shapes to work against.
6. **Frontend as a full-stack demonstration** — the assessment has no frontend requirement, but this is a full-stack role. A lightweight React UI shows end-to-end thinking and is more useful than a Postman collection for verifying the system.

I chose TDD throughout because the feedback loop catches interface mismatches early — especially useful when building a pipeline where services call each other.

I built this repository from scratch, not from a generator. Every file has a reason to be there.

---

## Problem Understanding

StrongMind needs visibility into GitHub activity to analyze repository usage and contributor behavior over time. This service ingests GitHub Push events from the public GitHub Events API, enriches them with actor and repository data, and stores everything in PostgreSQL for future querying and analysis.

---

## Architecture

### Components

- **Rails 7.1 API-only app** — orchestrates ingestion, enrichment, and serves a JSON:API query layer
- **PostgreSQL** — system of record for raw and structured event data
- **Redis + Sidekiq** — background job processing for continuous scheduled ingestion with retry and exponential backoff
- **React + RTK Query (Vite)** — lightweight frontend for browsing, filtering, and searching ingested data
- **GithubEventsClient** — handles all GitHub API requests, reads rate limit headers, raises on exhaustion
- **IngestionService** — fetch → filter → persist pipeline; runs manually via `docker compose run --rm ingest` or continuously via Sidekiq
- **EnrichmentService** — inline enrichment after each event is saved; fetches actor and repository detail URLs from the event payload
- **AvatarDownloadService** — downloads contributor avatars via ActiveStorage; skips already-attached, bounded by scheduled cleanup

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

---

## Story Breakdown

The assessment defines four stories. Rather than implementing them sequentially,
I broke them down by dependency — what must exist before something else can work.

**Story 1 (Ingest Push Events) and Story 2 (Persist Structured Data)** are tightly
coupled — you can't persist structured fields without the schema, and ingestion
without persistence is meaningless. I split them into three phases:

1. **Data models** — schema and validations first, since every service writes here
2. **GitHub client** — isolated HTTP layer that handles rate limits before any service uses it
3. **Ingestion service** — the pipeline that ties client, parser, and models together

**Story 3 (Enrich Push Events)** depends on ingestion producing records to enrich:

4. **Enrichment** — fetches actor/repo detail URLs, skips already-enriched records

**Story 4 (Operability)** isn't a phase — it's woven into every phase. Each service
logs structured output from the start. But a final pass ensures consistency:

5. **Observability** — unified log format, per-event error handling, no crash-loops

Four additional phases round out the deliverable:

6. **Background jobs** — Sidekiq + Redis for continuous polling with 3 retries and exponential backoff
7. **API layer** — JSON:API read endpoints with filtering over the stored data
8. **React frontend** — RTK Query dashboard replacing Postman; filter, search, and live updates
9. **Avatar storage** — ActiveStorage for contributor avatars with skip-if-exists and bounded cleanup

---

## Key Tradeoffs and Assumptions

- **Inline enrichment**: Enrichment runs synchronously after each event is persisted. Given the rate limit budget (60 req/hour unauthenticated) and the skip-if-already-enriched guard, this is fast enough and keeps the runtime dependency footprint minimal.
- **No authentication token**: Per requirements. The system stays within the 60 req/hour limit through header-aware rate limiting and skip-if-already-enriched logic.
- **Dual ingestion modes**: Manual via `docker compose run --rm ingest` or continuous via Sidekiq scheduled job. Sidekiq retries up to 3 times with exponential backoff — no crash-loops on transient GitHub API failures.

---

## Rate Limiting

GitHub's unauthenticated API allows 60 requests/hour. The client:
- Reads `X-RateLimit-Remaining` and `X-RateLimit-Reset` on every response
- Logs the remaining budget after each request
- Raises `GithubEventsClient::RateLimitedError` when remaining hits 0, with the reset timestamp logged
- Handles 429 responses with `Retry-After`

Enrichment skips actors and repositories whose `raw_payload` is already populated, preventing redundant API calls on repeated ingestion runs.

---

## Idempotency and Restart Safety

- `PushEvent` records are skipped if `github_id` already exists — re-running ingestion is safe
- `Actor` and `Repository` use `find_or_create_by(github_id:)` — no duplicates created
- Enrichment checks `raw_payload.present?` before fetching — no redundant network calls

---

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

---

## Testing Strategy

RSpec with a strict red-green-refactor TDD cycle: specs are written first and fail, then the minimum implementation is written to make them pass, then refactored if needed.

- **Model specs** — validations, uniqueness constraints, associations (Shoulda Matchers + FactoryBot)
- **Service specs** — `GithubEventsClient`, `IngestionService`, `EnrichmentService`, `AvatarDownloadService` tested in isolation with WebMock (no real HTTP)
- **Job specs** — `IngestionJob` delegates correctly and handles failures
- **Request specs** — JSON:API endpoints return correct format, status codes, pagination, and filtering

I chose to stub all external HTTP because the GitHub API is rate-limited and non-deterministic. WebMock ensures tests are fast, repeatable, and don't consume API budget. FactoryBot keeps test data consistent with the real schema.

---

## What Was Intentionally Not Built

- **User authentication** — internal service, no auth layer needed
- **Advanced analytics / reporting** — the JSON:API layer supports basic querying; dashboards are out of scope
