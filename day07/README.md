# Sprint Items API — Day 7 (Docker done right)

A small FastAPI service used through the DevOps sprint.
**Day 7 version:** small non-root image + Compose stack with Postgres.
Other versions: Day 6 in `capstone/`, Day 8 (CI) in `day08/`.

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
```

## Run the tests (no local Python needed)
```bash
docker run --rm -v "$PWD":/src -w /src python:3.12-slim \
  sh -c "pip install -q --root-user-action=ignore -r requirements-dev.txt && pytest -v -p no:cacheprovider"
```

## Configuration (environment variables)
| Variable | Used by | Meaning |
|---|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `db` | Database user, password and name, created on first start |
| `DATABASE_URL` | `app` | `postgresql://user:password@db:5432/db` — built by Compose from the values above |
| `APP_ENV` | `app` | `dev` / `test` / `prod` (default `dev`) |

Values live in `.env` (**git-ignored**). `.env.example` lists the keys with dummy values.

## The Dockerfile, line by line
| Line | What it does | Why |
|---|---|---|
| `FROM python:3.12-alpine AS builder` | Stage 1 on Alpine, named `builder` | Alpine is ~3× smaller than `-slim`; FastAPI and uvicorn ship Alpine wheels |
| `WORKDIR /build` | Working folder for the build stage | Keeps build files tidy |
| `RUN python -m venv /opt/venv` | Creates a virtual env | All packages in one folder that's easy to copy |
| `ENV PATH="/opt/venv/bin:$PATH"` | Uses the venv's `pip` and `python` | So packages install into `/opt/venv` |
| `COPY requirements.txt .` | Copies only the dependency list | Keeps the install layer cached when code changes |
| `RUN pip install --no-cache-dir -r requirements.txt` | Installs runtime dependencies | No pip cache left in the layer |
| `FROM python:3.12-alpine` | Stage 2 starts fresh | Nothing from stage 1 ships unless copied |
| `RUN adduser -D -u 10001 app` | Creates user `app` (UID 10001, no password) | For running as non-root |
| `COPY --from=builder /opt/venv /opt/venv` | Takes only the installed packages | The build stage is thrown away |
| `ENV PATH=… PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1` | venv on the path; no `.pyc`; unbuffered logs | Logs reach `docker logs` immediately |
| `WORKDIR /app` · `COPY app/ ./app/` | The application code | Owned by root, readable by `app` — the app can't modify itself |
| `USER app` | Everything after, and the container, runs as `app` | Least privilege |
| `EXPOSE 8000` | Documents the port | Above 1024, so non-root can bind it |
| `HEALTHCHECK … urlopen('http://127.0.0.1:8000/health')` | Docker calls `/health` every 10 s | Python instead of `curl` (not in Alpine) |
| `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]` | Starts the API | Exec form; `0.0.0.0` so the published port reaches it |

## compose.yaml
| Part | Meaning |
|---|---|
| `name: capstone` | Fixed project name — no clash with other folders |
| `db` · `postgres:16-alpine` | Postgres, data on the named volume `pgdata`, health check `pg_isready` |
| `app` · `build: .` · `image: capstone:0.2` | Builds this Dockerfile and tags the result |
| `DATABASE_URL: …@db:5432/…` | Config as an env var; `db` is the service name |
| `ports: "8088:8000"` | Only the app is published; Postgres stays internal |
| `depends_on: … condition: service_healthy` | App starts after Postgres is ready |
| `restart: unless-stopped` | Restart after a crash or reboot |

## Image facts
| | v0.1 (Day 6, `capstone/`) | **v0.2 (Day 7, `day07/`)** |
|---|---|---|
| Base | `python:3.12-slim` | **`python:3.12-alpine`**, multi-stage |
| Size | ~202 MB | **~117 MB** (under 150) |
| Runs as | root | **`app` (uid 10001)** |
| Health check | — | **`/health` every 10 s** |

Measured: multi-stage on `-slim` was *bigger* (239 MB) — the base image is what made the difference.
