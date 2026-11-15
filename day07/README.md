[⬅ Back to index](../README.md)

# Day 7 — Docker Done Right (Week 2 · Day 2)

**Date:** 2026-11-15
**Topic:** multi-stage builds, slim base images, non-root user, `.dockerignore`, Docker Compose
**Reading:** *Dockerfile best practices* (docs.docker.com) · *The Twelve-Factor App* (12factor.net): config, logs, dev/prod parity
**Where:** WSL Ubuntu 24.04 + Docker Desktop (Engine `29.6.1`, Compose `v5.2.0`)
**Cost:** $0 — everything ran locally.
**Lab (later):** capstone image under 150 MB and non-root; `compose.yaml` with the app + Postgres, all config as env vars.

| Part | Content |
|---|---|
| 📖 Cheat sheet | Dockerfile best practices and Compose commands at a glance |
| Sections 1–7 | Definitions with examples, and every command explained |
| Check-your-understanding answers | All 7 sections |
| Key takeaways | What to remember |

---

## 📖 Cheat sheet

### Dockerfile best practices
| Practice | How |
|---|---|
| Small base | `FROM python:3.12-slim` (not the 1 GB full image) |
| Pin versions | `python:3.12-slim`, `fastapi==0.163.1` — never `latest` |
| Cache-friendly order | `COPY requirements.txt` → `RUN pip install` → `COPY app/` |
| No caches in layers | `pip install --no-cache-dir` · `apt-get install --no-install-recommends … && rm -rf /var/lib/apt/lists/*` (same `RUN`) |
| Multi-stage | `FROM … AS builder` … `FROM …` + `COPY --from=builder …` |
| Non-root | `RUN useradd --create-home --uid 10001 app` → `USER app` (after installs, before `CMD`) |
| `.dockerignore` | `.git/`, `.venv/`, caches, `tests/`, `.env`, `*.pem` |
| Exec-form `CMD` | `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]` |
| Health check | `HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"` |
| No secrets | Never `ENV`/`COPY` passwords; pass them at run time |

### Compose commands
| Goal | Command |
|---|---|
| Start everything (background) | `docker compose up -d` |
| Start one service | `docker compose up -d db` |
| Rebuild, then start | `docker compose up -d --build` |
| Status (incl. stopped) | `docker compose ps` · `docker compose ps -a` |
| Logs | `docker compose logs -f db` |
| Shell / command in a running service | `docker compose exec db sh` |
| One-off command | `docker compose run --rm client` |
| Stop, keep containers | `docker compose stop` → `docker compose start` |
| Remove containers + network (keep data) | `docker compose down` |
| …and delete volumes (data!) | `docker compose down -v` |
| Check the file | `docker compose config` · `docker compose config --services` |

---

## Section 1 — Image size and base images

| Term | Definition | Example |
|---|---|---|
| **Why size matters** | Smaller images pull faster (CI, deploys, scaling), start faster, cost less, and have fewer packages to attack. | 1 GB vs 120 MB → ~8× faster pull |
| **Attack surface** | Every extra package (compilers, shells, tools) is something to exploit and something scanners flag. | `gcc` in production = needless risk |
| **Full image** | The whole OS plus build tools — easy but big. | `python:3.12` ≈ 1 GB |
| **`-slim`** | Debian with extras removed — the usual default for Python. | `python:3.12-slim` ≈ 120–130 MB |
| **`-alpine`** | Tiny Linux with musl libc; some Python packages need compiling or behave differently. | `python:3.12-alpine` ≈ 50–60 MB |
| **Distroless** | No shell or package manager — only the runtime and the app. Smallest attack surface, harder to debug. | `gcr.io/distroless/python3` |
| **`scratch`** | An empty image, for single static binaries (Go, Rust). | `FROM scratch` |
| **Pin the tag (and digest)** | Repeatable builds; the digest pins the exact content. | `python:3.12-slim@sha256:…` |
| **What makes images big** | Base, build tools, package caches, docs, and files that shouldn't be there. | Capstone v0.1: 202 MB |

```bash
docker pull python:3.12-slim
docker pull python:3.12-alpine
docker pull python:3.12
docker images python --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
docker run --rm python:3.12-slim sh -c 'which gcc || echo "no gcc in slim"'
docker run --rm python:3.12 sh -c 'which gcc'
docker rmi python:3.12 python:3.12-alpine
```
| Part | Meaning |
|---|---|
| `docker pull python:<tag>` | Download each variant of the same Python version |
| `docker images python --format 'table …'` | Table of name:tag and size to compare |
| `which gcc \|\| echo …` | Is a C compiler present? `slim`: no · full: yes |
| `docker rmi …` | Remove the images you won't use |

---

## Section 2 — Multi-stage builds

| Term | Definition | Example |
|---|---|---|
| **The problem** | Building needs tools that running doesn't; in one stage they all ship. | `gcc` used to build, still in production |
| **Multi-stage build** | Several `FROM`s in one Dockerfile; early stages build, the last stage copies only the results. | `FROM … AS builder` … `FROM …` |
| **Stage name (`AS`)** | Names a stage so later stages can refer to it. | `FROM python:3.12-slim AS builder` |
| **`COPY --from=`** | Copy files from an earlier stage instead of the project. | `COPY --from=builder /opt/venv /opt/venv` |
| **Only the last stage ships** | Earlier stages (tools, caches, source) are discarded. | The builder's tools never reach production |
| **venv as hand-off** | Install Python packages into one folder and copy it. | `/opt/venv` |
| **`--target`** | Build only up to a named stage (e.g. a test stage in CI). | `docker build --target test .` |
| **Honest note** | With pure-Python packages on `-slim` the saving is small; the big wins are compiled packages and Go/Java binaries. | Measure it in the lab |

```dockerfile
# ---- Stage 1: build the dependencies ----
FROM python:3.12-slim AS builder
WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Stage 2: the runtime image ----
FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY app/ ./app/
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
| Line | Meaning |
|---|---|
| `FROM … AS builder` | Stage 1, named `builder` |
| `python -m venv /opt/venv` | Packages go into one self-contained folder |
| `ENV PATH="/opt/venv/bin:$PATH"` | `pip` and `python` now mean the venv's copies |
| `RUN pip install --no-cache-dir …` | Install into `/opt/venv`, without pip's cache |
| Second `FROM python:3.12-slim` | Stage 2 starts fresh — nothing from stage 1 unless copied |
| `COPY --from=builder /opt/venv /opt/venv` | Take only the installed packages |
| `COPY app/ ./app/` · `CMD […]` | The code and the start command, as on Day 6 |

---

## Section 3 — Running as a non-root user

| Term | Definition | Example |
|---|---|---|
| **Default = root** | Without `USER`, the container process runs as root (UID 0). | `docker exec capstone id` → `uid=0(root)` |
| **The risk** | An exploited app bug gives root inside the container — and with a kernel/Docker flaw, possibly the host. | Remote-code bug in a framework |
| **Least privilege** | The app needs to read its code and listen on a port — not root. | Day 1's rule, for containers |
| **Create a user** | A dedicated system user, no password, fixed UID. | `RUN useradd --create-home --uid 10001 app` |
| **`USER`** | Switches the user for later instructions **and** the running container. | `USER app` |
| **Placement** | After installs (they need root), before `CMD`. | `RUN pip install …` → `USER app` → `CMD` |
| **File ownership** | Copied files are owned by root (readable). Folders the app writes to must belong to the user. | `COPY --chown=app:app app/ ./app/` |
| **Ports below 1024** | Only root can bind them; listen high inside, map at run time. | App on `8000`, `-p 80:8000` |
| **Numeric UID** | Lets Kubernetes verify "not root". | `USER 10001` |

```dockerfile
FROM python:3.12-slim
WORKDIR /app
RUN useradd --create-home --uid 10001 app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
USER app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
| Line | Meaning |
|---|---|
| `useradd --create-home --uid 10001 app` | Create user `app` with a home folder and a fixed UID |
| `RUN pip install …` | Still root here — installing needs it |
| `USER app` | Every later step and the container process run as `app` |
| Port `8000` | Above 1024, so a non-root user can bind it |

```bash
docker run --rm python:3.12-slim id
docker run --rm --user 10001 python:3.12-slim id
docker run --rm --user 10001 python:3.12-slim sh -c 'touch /etc/test'
docker run --rm python:3.12-slim sh -c 'touch /etc/test && echo "root can write /etc"'
```
| Part | Meaning |
|---|---|
| `id` | Show which user the container runs as → `uid=0(root)` by default |
| `--user 10001` | Override the user at run time → `uid=10001` |
| `touch /etc/test` as 10001 | `Permission denied` — a non-root process can't change system files |
| Same as root | Works — exactly the power you don't want an attacker to have |

---

## Section 4 — `.dockerignore` and other best practices

| Term | Definition | Example |
|---|---|---|
| **Build context** | The folder `docker build .` sends to the builder before building. | `transferring context: 52MB` |
| **`.dockerignore`** | Patterns of files not sent to the builder — `COPY . .` can't pick them up. | `.venv/`, `.git/` |
| **Speed** | Smaller context = faster builds and a more stable cache. | No `.git/` → commits don't break `COPY . .` |
| **Safety** | Keeps secrets and junk out of the image. | `.env`, `*.pem`, `.aws/` |
| **Patterns** | `.gitignore` style: `*`, `**`, `!` exceptions. | `*.md` then `!README.md` |

```text
.git/
.gitignore
.venv/
__pycache__/
*.pyc
.pytest_cache/
tests/
requirements-dev.txt
.env
*.pem
Dockerfile
compose.yaml
*.md
!README.md
```

| Practice | Why | Example |
|---|---|---|
| **Pin versions** | Repeatable builds | `FROM python:3.12-slim` |
| **Order for the cache** | Rarely-changing first, code last | requirements → install → code |
| **Clean up in the same `RUN`** | A later `RUN rm` doesn't shrink the image (64.6 MB vs 12.1 MB, Day 6) | `apt-get install … && rm -rf /var/lib/apt/lists/*` |
| **`--no-cache-dir` / `--no-install-recommends`** | Leave out caches and optional packages | `pip install --no-cache-dir …` |
| **`COPY` specific paths** | Only what the app needs | `COPY app/ ./app/` |
| **`COPY` over `ADD`** | Predictable | `COPY app.tar.gz .` |
| **One process per container** | Restart and scale separately | API and Postgres in two containers |
| **Exec-form `CMD`** | Signals reach the app; `docker stop` works | `CMD ["uvicorn", …]` |
| **Non-root `USER`** | Least privilege | `USER 10001` |
| **`HEALTHCHECK`** | Docker/Compose know if the app really works | Python one-liner (no `curl` in `-slim`) |
| **No secrets in the image** | `ENV`/`COPY`/`ARG` values stay in the layers | Pass at run time |
| **Labels** | Record source and version | `LABEL org.opencontainers.image.source="…"` |
| **Scan the image** | Find known vulnerabilities (Day 8) | `trivy image capstone:0.2` |

```bash
mkdir -p ~/practice/day7-ctx && cd ~/practice/day7-ctx
printf 'FROM alpine:3.20\nCOPY . /ctx\nCMD ["ls","-la","/ctx"]\n' > Dockerfile
echo "real app file" > app.txt
dd if=/dev/zero of=junk.bin bs=1M count=50 status=none
docker build --progress=plain -t ctx:big . 2>&1 | grep 'transferring context'
echo "junk.bin" > .dockerignore
docker build --progress=plain -t ctx:small . 2>&1 | grep 'transferring context'
docker run --rm ctx:small
docker rmi ctx:big ctx:small && cd ~ && rm -rf ~/practice/day7-ctx
```
| Part | Meaning |
|---|---|
| `printf '…' > Dockerfile` | A tiny Dockerfile that copies the whole context |
| `dd if=/dev/zero of=junk.bin bs=1M count=50 status=none` | Create a 50 MB junk file silently |
| `--progress=plain … \| grep 'transferring context'` | Show how much was sent to the builder → ~52 MB |
| `echo "junk.bin" > .dockerignore` | Exclude it |
| Second build | Only a few bytes sent |
| `docker run --rm ctx:small` | `junk.bin` isn't in `/ctx` |

---

## Section 5 — The Twelve-Factor App

**Twelve-Factor App:** 12 rules (12factor.net) for apps that deploy cleanly to the cloud and containers.

| # | Factor | One line | In the capstone |
|---|---|---|---|
| I | Codebase | One repo, many deploys | One `capstone/` |
| II | Dependencies | Declare and isolate them | Pinned `requirements.txt` in the image |
| **III** | **Config** | **Config in the environment** | `DATABASE_URL`, `APP_ENV` |
| IV | Backing services | A database is an attached resource | Postgres via `DATABASE_URL` |
| V | Build, release, run | Build image → add config → run | `docker build` → `docker run -e …` |
| VI | Processes | Stateless; state in backing services | In-memory `ITEMS` breaks it; Postgres fixes it |
| VII | Port binding | The app serves on its own port | uvicorn on `8000` |
| VIII | Concurrency | Scale with more processes | More containers / replicas (Day 10) |
| IX | Disposability | Fast start, graceful stop | Exec-form `CMD` |
| **X** | **Dev/prod parity** | **Keep environments alike** | Same image; Postgres locally via Compose |
| **XI** | **Logs** | **Logs as streams to stdout** | uvicorn → stdout → `docker logs` |
| XII | Admin processes | One-off tasks with the same image/config | `docker compose run app …` |

| Term | Definition | Example |
|---|---|---|
| **Config** | Anything that differs between environments. | `DATABASE_URL`, credentials, `LOG_LEVEL` |
| **Not config** | Same everywhere → stays in code. | Route paths like `/items` |
| **The test** | Could the code be open-sourced right now without leaking a credential? | A password in `main.py` fails |
| **Logs as a stream** | The app writes to stdout/stderr; the platform stores them. | `docker logs -f`, CloudWatch (Day 13) |
| **No log files in containers** | They fill the writable layer and vanish with it. | No `/app/logs/app.log` |
| **Structured logs** | One event per line, key=value or JSON. | `level=INFO path=/items status=200` |
| **Dev/prod parity** | Close the time, people and tools gaps; same image everywhere. | Postgres in dev too, not SQLite |

```bash
docker run --rm -e APP_ENV=prod -e LOG_LEVEL=debug python:3.12-slim \
  python -c "import os; print('env=', os.getenv('APP_ENV','dev'), 'level=', os.getenv('LOG_LEVEL','info'))"
docker run --rm python:3.12-slim \
  python -c "import os; print('env=', os.getenv('APP_ENV','dev'), 'level=', os.getenv('LOG_LEVEL','info'))"
docker run -d --name logdemo python:3.12-slim \
  python -u -c "import time; [print(f'level=INFO event=tick n={i}', flush=True) or time.sleep(1) for i in range(5)]"
sleep 6 && docker logs logdemo
docker rm -f logdemo
```
| Part | Meaning |
|---|---|
| `-e APP_ENV=prod -e LOG_LEVEL=debug` | Config passed from outside → `env= prod level= debug` |
| `os.getenv('APP_ENV','dev')` | Read the variable, with a safe default |
| Second run (no `-e`) | Defaults apply → `env= dev level= info` |
| `python -u -c "…"` | `-u` = unbuffered; prints 5 structured log lines to stdout |
| `docker logs logdemo` | Docker captured the stream — no log file anywhere |

---

## Section 6 — Docker Compose basics

| Term | Definition | Example |
|---|---|---|
| **Docker Compose** | Describes a multi-container app in one YAML file and runs it with one command. | `docker compose up` |
| **`compose.yaml`** | The file: services, ports, env vars, volumes, networks. | Project folder |
| **Service** | One container definition. | `web`, `db`, `app` |
| **`image:` vs `build:`** | Use an existing image, or build from a Dockerfile. | `image: postgres:16` · `build: .` |
| **Project** | Everything Compose creates for one folder; prefixed with the folder name. | `day7-web-1` |
| **Default network** | All services share one private network automatically. | `day7_default` |
| **Service name = hostname** | Services reach each other by name via Docker DNS — no `-p`. | `http://web`, `db:5432` |
| **`ports:`** | Publish a port to your machine — only what must be reachable from outside. | `"8089:80"` |
| **`depends_on:`** | Start order; by default doesn't wait for "ready". | `depends_on: [web]` |
| **Desired state** | `up` makes reality match the file; re-running applies only changes. | Edit a port → only that service recreated |
| **Compose v2** | Built into Docker as `docker compose`; `docker-compose` is retired. | `v5.2.0` |

```yaml
services:
  web:
    image: nginx:1.27
    ports:
      - "8089:80"
  pinger:
    image: alpine:3.20
    command: sh -c 'while true; do wget -qO- http://web | grep -o "<title>.*</title>"; sleep 2; done'
    depends_on:
      - web
```
| Line | Meaning |
|---|---|
| `services:` | The containers in this app |
| `image: nginx:1.27` | Run this image as service `web` |
| `ports: - "8089:80"` | Host 8089 → container 80 |
| `command:` | Override the image's default command |
| `wget -qO- http://web` | Reach `web` **by its service name** |
| `depends_on: - web` | Start `web` first |

```bash
docker compose config --services
docker compose up -d
docker compose ps
docker compose logs pinger
curl -s localhost:8089 | grep -o '<title>.*</title>'
docker compose exec web getent hosts pinger
docker network ls | grep day7
docker compose down
```
| Part | Meaning / result |
|---|---|
| `config --services` | Parse the file, list services → `web`, `pinger` |
| `up -d` | Create the network and start everything in the background |
| `ps` | `web running 0.0.0.0:8089->80/tcp` · `pinger running` (no ports) |
| `logs pinger` | `<title>Welcome to nginx!</title>` — pinger reached `web` by name |
| `curl localhost:8089` | Your machine reaches `web` through `ports:` |
| `exec web getent hosts pinger` | Docker DNS resolves the name → `172.18.0.x pinger` |
| `network ls \| grep day7` | The automatic project network `day7_default` |
| `down` | Remove containers and network in one command |

### Project vs service vs container
| Name | What it is | From | Used in |
|---|---|---|---|
| `day7db` | **Project** | Folder name (or `-p` / `name:`) | Prefix of everything Compose creates |
| `db`, `client` | **Service** | Keys under `services:` | `docker compose stop db`, `logs db`, `exec db …` |
| `day7db-db-1` | **Container** | `<project>-<service>-<n>` | Plain `docker` commands |

> Two folders with the **same name** share one project — their containers, networks and volumes clash. Use `docker compose -p <name>` or `name: <name>` at the top of `compose.yaml`.

### stop vs pause vs down
| Command | Containers | Network | Volumes | Undo with |
|---|---|---|---|---|
| `docker compose stop` | Stopped, **kept** | Kept | Kept | `docker compose start` |
| `docker compose pause` | Frozen in memory | Kept | Kept | `docker compose unpause` |
| `docker compose down` | **Removed** | Removed | Kept | `docker compose up -d` |
| `docker compose down -v` | Removed | Removed | **Deleted** | `up -d` — data gone |

---

## Section 7 — Compose networks, volumes, health checks and env

| Term | Definition | Example |
|---|---|---|
| **Named volume in Compose** | Declared under top-level `volumes:`; data survives `down`/`up`. | `- pgdata:/var/lib/postgresql/data` |
| **`environment:`** | Env vars for a service, in the file. | `POSTGRES_DB: app` |
| **`env_file:`** | Load a service's env vars from a file. | `env_file: .env` |
| **`.env` + `${VAR}`** | Compose reads `.env` and fills `${VAR}` in `compose.yaml`. | `${POSTGRES_PASSWORD}` |
| **`$$`** | A literal `$` for the container's shell (not substituted by Compose). | `pg_isready -U $${POSTGRES_USER}` |
| **`.env` is a secret** | In `.gitignore`; commit `.env.example` with dummy values. | `cp .env.example .env` |
| **`healthcheck:`** | A command run regularly → `healthy` / `unhealthy`. | `pg_isready` |
| **`condition: service_healthy`** | Wait until the dependency is actually ready. | App waits for Postgres |
| **`restart:`** | Behaviour when a container stops: `no`, `always`, `on-failure`, `unless-stopped`. | `restart: unless-stopped` |
| **Custom networks** | Separate networks so only the app reaches the DB. | `networks: [backend]` |
| **Don't publish the DB** | The app uses `db:5432` internally; publish only on `127.0.0.1` if a local tool needs it. | `"127.0.0.1:5432:5432"` |
| **Long-running vs one-off** | A server keeps running; a task runs once and exits with code 0. | `db` stays `Up` · `client` → `Exited (0)` |

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 10

  client:
    image: postgres:16
    environment:
      PGHOST: db
      PGUSER: ${POSTGRES_USER}
      PGPASSWORD: ${POSTGRES_PASSWORD}
      PGDATABASE: ${POSTGRES_DB}
    command: ["psql", "-c", "SELECT 'connected to ' || current_database() AS status;"]
    depends_on:
      db:
        condition: service_healthy

volumes:
  pgdata:
```
| Line | Meaning |
|---|---|
| `image: postgres:16` | Official Postgres, major version pinned |
| `POSTGRES_USER / PASSWORD / DB` | The image creates this user and database on first start |
| `${POSTGRES_USER}` | Filled from `.env` — no password in `compose.yaml` |
| `pgdata:/var/lib/postgresql/data` | Postgres data on a named volume |
| `test: ["CMD-SHELL", "pg_isready …"]` | Postgres's own "ready?" check, run through a shell |
| `interval / timeout / retries` | Every 5 s, 3 s each, unhealthy after 10 failures |
| `PGHOST: db` | The client connects to the host `db` — the service name |
| `command: ["psql", "-c", "…"]` | One query, then exit |
| `condition: service_healthy` | The client starts only after `db` is healthy |
| Top-level `volumes: pgdata:` | Declares the named volume |

**`.env`** (in `.gitignore`):
```text
POSTGRES_USER=app
POSTGRES_PASSWORD=change-me-locally
POSTGRES_DB=app
```

```bash
mkdir -p ~/practice/day7db && cd ~/practice/day7db
printf 'POSTGRES_USER=app\nPOSTGRES_PASSWORD=change-me-locally\nPOSTGRES_DB=app\n' > .env
docker compose config | grep -E 'POSTGRES_USER|condition'
docker compose up -d db
docker compose ps
docker compose run --rm client
docker compose exec db psql -U app -d app -c "CREATE TABLE items(id serial, name text); INSERT INTO items(name) VALUES ('laptop stand');"
docker compose down
docker compose up -d db && sleep 15
docker compose exec db psql -U app -d app -tAc "SELECT name FROM items;"
docker compose up -d
docker compose ps -a
docker compose logs client
docker compose down -v
docker volume ls | grep day7db || echo "volume gone"
```
| Part | Meaning / result |
|---|---|
| `printf '…' > .env` | Write the three config values |
| `config \| grep …` | `POSTGRES_USER: app`, `condition: service_healthy` — `${VAR}` was filled |
| `up -d db` | Start only the `db` service |
| `ps` | `db … Up (healthy)` after the health check passes |
| `run --rm client` | One-off container: waits for healthy, prints `connected to app`, then is removed |
| `exec db psql -U app -d app -c "…"` | Run SQL inside the db container → `INSERT 0 1` |
| `down` → `up -d db` → `SELECT` | `laptop stand` — the named volume kept the data |
| `-tAc` | psql: tuples only, unaligned, run one command — just the value |
| `up -d` (all) → `ps -a` | `client` shows `Exited (0)` — a finished one-off task, not an error |
| `logs client` | Its output is still readable after it exited |
| `down -v` → `volume ls` | `volume gone` — `-v` deletes the data |

---

## Check-your-understanding answers

| Section | Q | Answer |
|---|---|---|
| 1 | Two reasons smaller is better? | Faster pulls/deploys/startup; smaller attack surface (also cheaper storage). |
| 1 | `-slim` vs `-alpine` for Python? | Alpine uses musl → many packages compile or misbehave; `-slim` uses standard wheels. |
| 2 | What's in the final image? | Only the last stage and what it copies in. |
| 2 | `COPY --from=builder` copies from? | An earlier stage of the same build. |
| 3 | Why `USER` after `pip install`? | Installing needs root. |
| 3 | App must write `/app/logs`? | `chown` that folder to the user (or `COPY --chown`) — better: log to stdout. |
| 3 | Why not port 80 as non-root? | Ports < 1024 are privileged; listen on 8000, map `-p 80:8000`. |
| 4 | Two reasons `.git/` is ignored? | Big; changes every commit (breaks the cache); may hold secrets. |
| 4 | Why install + clean in one `RUN`? | Each `RUN` is a layer; deleting later only hides the files. |
| 4 | Why app and Postgres in two containers? | Restart, scale, update and back up separately. |
| 5 | Is `/items` config? The DB password? | `/items` no (same everywhere); the password yes (differs, secret). |
| 5 | Why no `/app/logs/app.log`? | Lost with the container, fills the layer; logs go to stdout. |
| 5 | Why Postgres locally, not SQLite? | Dev/prod parity — different behaviour hides bugs until production. |
| 6 | How does `pinger` find `web`? | Same project network + Docker DNS resolves service names. |
| 6 | Why only `web` has `ports:`? | Only it must be reached from the laptop; services talk internally. |
| 6 | `down` vs `down -v`? | `down` keeps named volumes; `-v` deletes them (and the data). |
| 7 | Why `service_healthy`? | Plain `depends_on` waits only for start; Postgres needs seconds before accepting connections. |
| 7 | Why `$$` in the healthcheck? | A literal `$` so the container's shell expands it, not Compose. |
| 7 | Where's the password, why `.gitignore`? | In `.env`; it's a secret — commit `.env.example` instead. |

---

## Key takeaways

| Topic | Remember |
|---|---|
| Base image | `-slim` by default; pin the tag; alpine/distroless only with reason |
| Multi-stage | Build in one stage, ship only the results; measure the saving |
| Non-root | `useradd` + `USER` after installs, before `CMD`; fixed UID; high ports |
| `.dockerignore` | Smaller context, stable cache, no secrets in the image |
| Layers | Install and clean in the same `RUN`; `--no-cache-dir` |
| Twelve-Factor | Config in env vars · logs to stdout · same image in every environment |
| Compose | One file, one command; services talk by name; publish only what's needed |
| Readiness | `healthcheck` + `condition: service_healthy` |
| Data | Named volumes survive `down`; only `down -v` deletes them |
| Lifecycle | `stop`/`start` keep containers; `down` removes them; one-off tasks exit with code 0 |
| Names | Project (folder) ≠ service (`db`) ≠ container (`day7db-db-1`) |
