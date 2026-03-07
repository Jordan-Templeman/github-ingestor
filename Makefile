.PHONY: up down migrate ingest test logs console

up:
	docker compose up --build

down:
	docker compose down --remove-orphans

migrate:
	docker compose run --rm app bundle exec rails db:migrate

ingest:
	docker compose run --rm ingest

test:
	docker compose run --rm test

logs:
	docker compose logs -f

console:
	docker compose run --rm app bundle exec rails console
