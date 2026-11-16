# Sprint Items API — the capstone app

A small FastAPI service used through the whole DevOps sprint.
Day 7 version: small non-root image + Compose stack with Postgres. The Day 6 version is in `capstone/`.

## Endpoints
| Method | Path | Returns |
|---|---|---|
| GET | `/health` | `{"status": "ok"}` — used by the Docker health check |
| GET | `/items` | All items |
| GET | `/items/{id}` | One item, or `404` |
| POST | `/items` | Creates an item from `{"name": "...", "price": 1.0}` → `201` |
| GET | `/docs` | Interactive API docs |

Items are kept **in memory** (they reset on restart). The app already receives `DATABASE_URL`; using it is a later step.

## Run the stack (app + Postgres)
```bash
cp .env.example .env          # then set a real POSTGRES_PASSWORD
docker compose up -d --build
docker compose ps             # both services "(healthy)"
curl localhost:8088/health
docker compose down           # keeps the database volume (down -v deletes it)
