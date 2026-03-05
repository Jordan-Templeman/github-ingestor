# StrongMind GitHub Ingestor

A Rails API service that ingests GitHub Push events, enriches them with actor and repository data, and stores everything in PostgreSQL for querying and analysis.

See [DESIGN.md](DESIGN.md) for architecture decisions and tradeoffs.

---

## Requirements

- Docker Desktop (macOS)
- Docker Compose

No other local dependencies required.

---

## How to Start the System

```bash
docker compose up --build
```

This starts the Rails app on `http://localhost:3000` and PostgreSQL. The database is created and migrated automatically on boot.

---

## How to Run Ingestion

```bash
docker compose run --rm ingest
```

Fetches events from the GitHub Public Events API, filters to PushEvents, persists them with structured fields and raw payloads, and enriches each event with actor and repository detail data.

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
[GithubClient] GET https://api.github.com/events status=200 rate_limit_remaining=58
[Ingestion] Fetched 30 events, 4 PushEvents
[Ingestion] Persisted push_event github_id=12345678901
[Enrichment] Fetching actor url=https://api.github.com/users/someuser
[Enrichment] Fetching repository url=https://api.github.com/repos/someuser/somerepo
[Ingestion] Complete — persisted: 4, skipped: 0
```

On a second run you should see skipped duplicates:

```
[Ingestion] Skipped duplicate github_id=12345678901
[Ingestion] Complete — persisted: 0, skipped: 4
```

### 2. Query the database directly

```bash
docker compose exec db psql -U postgres -d github_ingestor_development
```

```sql
SELECT id, github_id, ref, head, before FROM push_events LIMIT 5;
SELECT id, github_id, login FROM actors LIMIT 5;
SELECT id, github_id, full_name FROM repositories LIMIT 5;
```

### 3. Query via the API

```
GET http://localhost:3000/api/v1/push_events
GET http://localhost:3000/api/v1/push_events/:id
GET http://localhost:3000/api/v1/actors
GET http://localhost:3000/api/v1/repositories
```

All endpoints return JSON:API format. Index endpoints support `limit` and `offset` query params.

### 4. Stream all logs

```bash
docker compose logs -f
```

---

## Postman Collection

Import `postman/github_ingestor.postman_collection.json` and `postman/github_ingestor.postman_environment.json` into Postman.

Set the `base_url` environment variable to `http://localhost:3000` (default).

---

## Rate Limiting

The GitHub unauthenticated API allows 60 requests/hour. The ingestion client reads `X-RateLimit-Remaining` on every response and logs the remaining budget. If the limit is exhausted, a `RateLimitedError` is raised with the reset timestamp logged. Re-running enrichment on subsequent runs skips already-enriched records, keeping API usage bounded.
