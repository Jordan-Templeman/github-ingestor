# StrongMind GitHub Ingestor

A Rails API service that ingests GitHub Push events, enriches them with actor and repository data, and stores everything in PostgreSQL for querying and analysis. Includes a React + TypeScript dashboard for browsing events.

See [DESIGN.md](DESIGN.md) for architecture decisions and tradeoffs.

---

## Requirements

- Docker Desktop
- Docker Compose

No other local dependencies required.

---

## How to Start the System

```bash
docker compose up --build
```

This starts:
- Rails API on `http://localhost:3000`
- React dashboard on `http://localhost:5173`
- PostgreSQL database

The database is created and migrated automatically on boot.

---

## How to Run Ingestion

```bash
docker compose run --rm ingest
```

Fetches events from the GitHub Public Events API, filters to PushEvents, persists them with structured fields and raw payloads, and batch-enriches unique actors and repositories with detail data. Uses ETag conditional requests to avoid redundant API calls on repeated runs.

---

## How to Run Tests

```bash
docker compose run --rm test
```

Runs the full RSpec suite with documentation formatter. No external network calls — all HTTP is stubbed via WebMock.

---

## How to Verify It's Working

### 1. Watch the logs during ingestion

```bash
docker compose run --rm ingest
```

Expected output:

```
[GithubEventsClient] GET https://api.github.com/events status=200 rate_limit_remaining=58
[IngestionService] fetched=30 push_events=4 persisted=4 skipped=0 errored=0
[EnrichmentService] Enriched actor login=someuser
[EnrichmentService] Enriched repository name=someuser/somerepo
```

On a second run you should see ETag cache hits:

```
[EnrichmentService] Skipped actor login=someuser (ETag matched, not modified)
[IngestionService] fetched=30 push_events=4 persisted=0 skipped=4 errored=0
```

### 2. Browse the dashboard

Open `http://localhost:5173` to see the React dashboard with:
- Push events table with actor avatars, repository names, and git references
- Filtering by actor and repository
- Paginated navigation

### 3. Query the database directly

```bash
docker compose exec db psql -U postgres -d github_ingestor_development
```

```sql
SELECT id, github_id, ref, head, before FROM push_events LIMIT 5;
SELECT id, github_id, login FROM actors LIMIT 5;
SELECT id, github_id, full_name FROM repositories LIMIT 5;
```

### 4. Query via the API

```
GET http://localhost:3000/api/v1/push_events
GET http://localhost:3000/api/v1/push_events/:id
GET http://localhost:3000/api/v1/actors
GET http://localhost:3000/api/v1/repositories
```

All endpoints return JSON:API format. Index endpoints support `limit` and `offset` query params.

### 5. Stream all logs

```bash
docker compose logs -f
```

---

## Postman Collection

Import `postman/github_ingestor.postman_collection.json` and `postman/github_ingestor.postman_environment.json` into Postman.

Set the `base_url` environment variable to `http://localhost:3000` (default).

---

## Rate Limiting

The GitHub unauthenticated API allows 60 requests/hour. The system manages this through:

- **Budget tracking** — checks `/rate_limit` before enrichment to know available requests
- **ETag caching** — conditional requests return 304 without counting against the limit
- **Batch deduplication** — N events sharing the same actor result in 1 API call, not N
- **Header monitoring** — logs `X-RateLimit-Remaining` on every response, raises on exhaustion
