# StrongMind GitHub Ingestor

A Rails API service that ingests GitHub Push events, enriches them with actor and repository data, and stores everything in PostgreSQL for querying and analysis.

See [DESIGN.md](DESIGN.md) for architecture decisions and tradeoffs.

---

## Requirements

- Docker Desktop (macOS)
- Docker Compose

No other local dependencies required.

---

## Make Commands

A `Makefile` is included for convenience:

| Command | Description |
|---------|-------------|
| `make up` | Build and start all services |
| `make down` | Stop and remove containers |
| `make migrate` | Run pending migrations |
| `make ingest` | Run ingestion |
| `make test` | Run the full test suite |
| `make logs` | Tail all service logs |
| `make console` | Open a Rails console |

---

## How to Start the System

```bash
make up
# or: docker compose up --build
```

This starts the Rails API on `http://localhost:3000`, PostgreSQL, Redis, Sidekiq (continuous ingestion), and the React frontend on `http://localhost:5173`. The database is created and migrated automatically on boot.

---

## How to Run Ingestion

```bash
make ingest
# or: docker compose run --rm ingest
```

Runs a one-off ingestion: fetches events from the GitHub Public Events API, filters to PushEvents, persists them with structured fields and raw payloads, and enriches each event with actor and repository detail data.

Ingestion also runs continuously via Sidekiq on a scheduled interval when the system is up. Manual runs are useful for immediate ingestion or testing.

---

## How to Run Tests

```bash
make test
# or: docker compose run --rm test
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

## Frontend

The React frontend is available at `http://localhost:5173` after `docker compose up --build`.

- Browse push events, actors, and repositories
- Filter by ref, actor login, or repository name
- Search across records
- Click any event to view the full payload
- Live updates via polling or manual refresh

---

## Rate Limiting

The GitHub unauthenticated API allows 60 requests/hour. The ingestion client reads `X-RateLimit-Remaining` on every response and logs the remaining budget. If the limit is exhausted, a `RateLimitedError` is raised with the reset timestamp logged. Re-running enrichment on subsequent runs skips already-enriched records, keeping API usage bounded.
