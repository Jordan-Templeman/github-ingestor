# Design Brief — GitHub Ingestor

## How I Approached This

The first thing I did was read the requirements carefully and resist the urge to immediately start building. The prompt explicitly says it cares more about how you think than how much you build — so I treated the planning step as real work.

I broke the problem down by asking: what is the smallest slice of working, verifiable behavior I can build first, and what does everything else depend on? That gave me a natural sequence of phases, each delivered as its own PR so that progress was reviewable and mergeable at every step.

I chose TDD throughout because the feedback loop catches interface mismatches early — especially useful when building a pipeline where services call each other.

I built this repository from scratch, not from a generator. Every file has a reason to be there.

---

## Phased Delivery

Each phase was scoped as a standalone deliverable with its own PR, tests, and review. This mirrors how I work in production — small, reviewable increments that build on each other.

| Phase | PR | What It Delivered |
|-------|----|----|
| Planning | [#2](https://github.com/Jordan-Templeman/github-ingestor/pull/2) | Story breakdown, architecture decisions, workflow tooling |
| 1 — Data Models | [#1](https://github.com/Jordan-Templeman/github-ingestor/pull/1) | Actor, Repository, PushEvent models with migrations, validations, and specs |
| 2 — GitHub Client | [#4](https://github.com/Jordan-Templeman/github-ingestor/pull/4) | GithubEventsClient with rate limit handling, error handling, WebMock specs |
| 3 — Ingestion Service | [#5](https://github.com/Jordan-Templeman/github-ingestor/pull/5) | Fetch → filter → persist pipeline, idempotency, per-event error isolation |
| 4 — Enrichment | [#6](https://github.com/Jordan-Templeman/github-ingestor/pull/6) | Actor/repo detail enrichment, SSRF protection, rate limit awareness |
| 6 — Background Jobs | [#7](https://github.com/Jordan-Templeman/github-ingestor/pull/7) | Continuous ingestion support via background jobs |
| 7 — JSON:API Layer | [#8](https://github.com/Jordan-Templeman/github-ingestor/pull/8) | REST endpoints with jsonapi-serializer, pagination, filtering |
| Extension C — Avatars | [#9](https://github.com/Jordan-Templeman/github-ingestor/pull/9) | AvatarDownloadService, local file storage, download after enrichment |
| 8 — React Dashboard | [#10](https://github.com/Jordan-Templeman/github-ingestor/pull/10) | RTK Query + MUI frontend with filtering, pagination, actor avatars |
| 10 — Cleanup & Optimization | *(this branch)* | ETag caching, batch dedup, rate limit budgeting, SSRF hardening, dead code removal |

**Why this order?** Data model first — everything else writes to and reads from the database. Client before service — the ingestion service depends on the HTTP client. Ingestion before enrichment — persist first, enrich second, so the core pipeline works even if enrichment has issues. API layer after data exists — serializers and controllers have real data shapes to work against. Frontend last — it reads from a stable API.

---

## Problem Understanding

StrongMind needs visibility into GitHub activity to analyze repository usage and contributor behavior over time. This service ingests GitHub Push events from the public GitHub Events API, enriches them with actor and repository data, and stores everything in PostgreSQL for future querying and analysis.

---

## Architecture

### Components

- **Rails 7.1 API-only app** — orchestrates ingestion, enrichment, and serves a JSON:API query layer
- **React + TypeScript frontend** — RTK Query dashboard with MUI, filtering by actor/repository, pagination
- **PostgreSQL** — system of record for raw and structured event data
- **GithubEventsClient** — handles all GitHub API requests, reads rate limit headers, raises on exhaustion
- **IngestionService** — fetch → filter → persist → batch enrich pipeline, runs on-demand via `docker compose run --rm ingest`
- **EnrichmentService** — batch enrichment after ingestion; deduplicates actors/repos, uses ETag conditional requests, tracks rate limit budget before making calls
- **AvatarDownloadService** — downloads actor avatars to local storage after enrichment

### Data Flow

```
GitHub Events API
       │
       ▼
GithubEventsClient.fetch
       │
       ▼
IngestionService.run
  ├── Filter to PushEvents only
  ├── For each event:
  │     ├── Skip if github_id already exists (idempotent)
  │     ├── find_or_create Actor and Repository
  │     └── Create PushEvent with raw_payload
  └── Batch enrich all persisted events:
        ├── Deduplicate actors and repositories
        ├── Check rate limit budget via /rate_limit endpoint
        ├── For each unique actor/repo:
        │     ├── Skip if budget exhausted
        │     ├── Send If-None-Match with cached ETag
        │     ├── On 304: skip update (cache hit)
        │     └── On 200: save raw_payload + ETag
        └── Download avatars for enriched actors
```

### Data Model

```
actors
  github_id, login, display_login, avatar_url, url, raw_payload, etag

repositories
  github_id, name, full_name, url, raw_payload, etag

push_events
  github_id, ref, head, before, push_id
  actor_id (FK), repository_id (FK)
  raw_payload
```

Raw payloads are stored on all three tables for audit and debug purposes. Structured fields on `push_events` (ref, head, before, push_id, repository identifier) are queryable without JSON parsing. ETag columns on actors and repositories enable conditional requests to avoid redundant API calls.

---

## Key Tradeoffs and Assumptions

- **Batch enrichment with deduplication**: Enrichment runs after all events in a batch are persisted. Unique actors and repositories are extracted first, so even if 10 events share the same actor, only one API call is made.
- **ETag conditional requests (discovered during implementation)**: My initial design used a simple `raw_payload.present?` guard to skip enrichment on already-enriched records. As I continued building, I realized this approach meant data would never refresh once initially fetched — a stale cache with no invalidation. I replaced it with ETag-based conditional requests: the service always checks with GitHub, but 304 responses don't count against the rate limit and don't update unchanged data. This was a better design that I arrived at through building, not upfront planning.
- **Rate limit budget tracking**: Before making enrichment calls, the service checks GitHub's `/rate_limit` endpoint to know how many requests remain. If the budget is exhausted, enrichment is skipped with a warning — the core ingestion pipeline is never blocked.
- **SSRF hardening**: All enrichment URLs are validated against the configured GitHub API host using `URI.parse` host comparison (not string prefix matching). URLs pointing to non-GitHub hosts are blocked and logged.
- **No authentication token**: Per requirements. The system stays within the 60 req/hour limit through ETag caching, batch deduplication, and budget-aware enrichment.
- **On-demand ingestion**: `IngestionService.run` is invoked explicitly. Continuous polling is not implemented — the operator decides when to ingest.
- **Frontend trade-offs**: The React dashboard uses MUI components directly rather than styled-components, and does not include Storybook, React Testing Library specs, or i18n translations. These are standard in production React apps but were omitted to keep scope focused on the backend pipeline demonstration.

---

## Rate Limiting

GitHub's unauthenticated API allows 60 requests/hour. The system manages this budget at multiple levels:

1. **GithubEventsClient** — reads `X-RateLimit-Remaining` and `X-RateLimit-Reset` on every response, logs the remaining budget, raises `RateLimitedError` when remaining hits 0 or on 429 responses
2. **EnrichmentService** — checks `/rate_limit` before starting enrichment to know the available budget, decrements a local counter per request, stops enrichment when budget is exhausted
3. **ETag caching** — conditional requests that return 304 do not count against the rate limit, making re-enrichment essentially free for unchanged records
4. **Batch deduplication** — N events sharing the same actor result in 1 API call, not N

---

## Idempotency and Restart Safety

- `PushEvent` records are skipped if `github_id` already exists — re-running ingestion is safe
- `Actor` and `Repository` use `find_or_create_by(github_id:)` — no duplicates created
- ETag-based enrichment means re-running enrichment on unchanged records returns 304 with no rate limit cost

---

## Observability

All services log structured lines to stdout via `Rails.logger`:

```
[GithubEventsClient] GET https://api.github.com/events status=200 rate_limit_remaining=58
[IngestionService] fetched=30 push_events=4 persisted=4 skipped=0 errored=0
[EnrichmentService] Enriched actor login=octocat
[EnrichmentService] Skipped actor login=octocat (ETag matched, not modified)
[EnrichmentService] Rate limit budget exhausted, skipping repository name=foo/bar
[EnrichmentService] Blocked non-GitHub URL for actor login=evil: http://evil.example.com
```

Malformed or unexpected payloads are rescued per-event: the error is logged with context and processing continues. The service does not crash-loop on transient failures.

---

## What Was Intentionally Not Built

- **Continuous polling** — ingestion is operator-triggered; a scheduler is out of scope
- **User authentication** — internal service, no auth layer needed
- **Object storage** (Extension C) — raw payloads are stored in PostgreSQL jsonb columns; avatars are downloaded to local storage
- **Advanced analytics / reporting** — the JSON:API layer supports basic querying; the React dashboard provides browsing and filtering
- **Storybook / RTL specs / i18n** — typically included in production React apps but omitted for scope
