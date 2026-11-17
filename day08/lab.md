[⬅ Back to labs](../SPRINT.md)

# Day 7 Lab — Small Non-Root Image and a Compose Stack with Postgres

**The task (sprint plan):** Get the image **under 150 MB, running as non-root**. Run a **`compose.yaml` stack of the app plus Postgres**, with **all config passed as env vars**.

**Date:** 2026-11-16 · **Where:** WSL Ubuntu 24.04 + Docker Desktop (Engine `29.6.1`, Compose `v5.2.0`) · **Cost:** $0
**Result:** folder `day07/` on the `labs` branch (PRs #11 and #12). Version: **minimal** — the Day 6 app unchanged; it receives `DATABASE_URL` but still keeps items in memory.

| Requirement | Result |
|---|---|
| Image under 150 MB | ✅ **117 MB** (Day 6: ~202 MB) |
| Running as non-root | ✅ `uid=10001(app)` + a `HEALTHCHECK` |
| `compose.yaml` with app + Postgres | ✅ `postgres:16-alpine`, health check, named volume, `service_healthy` |
| All config as env vars | ✅ `DATABASE_URL`, `APP_ENV` from a git-ignored `.env` |

| Part | What | Time |
|---|---|---|
| 1 | Setup: Docker, branch, a `day07/` folder from the Day 6 app | 5 min |
| 2 | Dockerfile v0.2: Alpine, multi-stage, non-root, health check | 15 min |
| 3 | `.env`, `compose.yaml`, run and prove the stack | 15 min |
| 4 | README, commit, PR into `labs`, merge | 10 min |

**Final layout**
```text
day07/
├── .dockerignore      + .env, .env.example, compose.yaml
├── .env               (local only, git-ignored — the real password)
├── .env.example       keys with dummy values (committed)
├── .gitignore         + .env
├── Dockerfile         Alpine, multi-stage, non-root, HEALTHCHECK
├── README.md          endpoints, config, Dockerfile and compose.yaml explained
├── compose.yaml       app + Postgres
├── app/               the Day 6 app, unchanged
├── tests/             the Day 6 tests, unchanged
├── pytest.ini · requirements.txt · requirements-dev.txt
```

---

## Part 1 — Setup

```bash
docker version --format '{{.Server.Version}}'
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker rm -f capstone web3 2>/dev/null
cd ~/Devops-Sprint-Wisam
git switch labs && git pull
git switch -c lab/day07-compose
cp -r capstone day07
cd day07
```
| Command | Meaning |
|---|---|
| `docker version --format '{{.Server.Version}}'` | Prints `29.6.1` only if Docker Desktop's engine is up |
| `docker ps -a --format 'table …'` | All containers (running and stopped) with status and ports |
| `docker rm -f capstone web3 2>/dev/null` | Remove leftover Day 6 containers so port 8088 is free; `2>/dev/null` hides "no such container" |
| `git switch labs && git pull` | Start from the latest labs branch |
| `git switch -c lab/day07-compose` | A topic branch for this lab |
| `cp -r capstone day07` | Start Day 7 from a **copy** of the Day 6 app — each day keeps its own folder |
| `cd day07` | Work in the new folder |

> **If `docker` "could not be found" or gives `Input/output error` in WSL:** Docker Desktop's engine stopped (often its **Resource Saver** after idle minutes). Restart Docker Desktop, then open a new WSL terminal. Prevent it: Settings → Resources → Advanced → turn off Resource Saver; Settings → General → start Docker Desktop at sign-in.

---

## Part 2 — The small, non-root image

### 2.1 The starting point
```bash
docker build -t capstone:0.1 .
docker images capstone:0.1
docker run --rm capstone:0.1 id
```
| Command | Meaning / result |
|---|---|
| `docker build -t capstone:0.1 .` | Build the unchanged Day 6 Dockerfile — the "before" |
| `docker images capstone:0.1` | **~202 MB** — over the limit |
| `docker run --rm capstone:0.1 id` | `uid=0(root)` — runs as **root** |

### 2.2 Measure before choosing (what I tested)
| Variant | Base | Stages | Size |
|---|---|---|---|
| Day 6 (`0.1`) | `python:3.12-slim` | 1 | ~202 MB |
| slim + multi-stage | `python:3.12-slim` | 2 | **239 MB — bigger** |
| **alpine + multi-stage (`0.2`)** | **`python:3.12-alpine`** | 2 | **117 MB** ✅ |

**Lesson:** the **base image** made the difference. Multi-stage saves little for pure-Python packages (nothing to compile); on `-slim` the venv even added its own copy of pip. Alpine works here because FastAPI, pydantic and uvicorn ship Alpine (musl) wheels.

### 2.3 The new Dockerfile
```bash
cat > Dockerfile <<'EOF'
# ---- Stage 1: install the dependencies into a virtual env ----
FROM python:3.12-alpine AS builder
WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Stage 2: the small runtime image ----
FROM python:3.12-alpine
RUN adduser -D -u 10001 app
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY app/ ./app/
USER app
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
```
| Line | What it does | Why |
|---|---|---|
| `FROM python:3.12-alpine AS builder` | Stage 1 on Alpine, named `builder` | Alpine ≈ 3× smaller than `-slim` |
| `WORKDIR /build` | Working folder for the build stage | Keeps build files tidy |
| `RUN python -m venv /opt/venv` | Creates a virtual env | All packages in one folder that's easy to copy |
| `ENV PATH="/opt/venv/bin:$PATH"` | Uses the venv's `pip` / `python` | So packages install into `/opt/venv` |
| `COPY requirements.txt .` | Only the dependency list | Install layer stays cached when code changes |
| `RUN pip install --no-cache-dir -r requirements.txt` | Installs FastAPI and uvicorn | No pip cache in the layer |
| `FROM python:3.12-alpine` | Stage 2 starts fresh | Nothing from stage 1 ships unless copied |
| `RUN adduser -D -u 10001 app` | User `app`, UID 10001, no password (`-D`) | Alpine's `adduser` (Debian: `useradd`) |
| `COPY --from=builder /opt/venv /opt/venv` | Takes only the installed packages | The build stage is thrown away |
| `ENV PATH=… PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1` | venv on the path; no `.pyc`; unbuffered logs | Logs reach `docker logs` immediately |
| `WORKDIR /app` · `COPY app/ ./app/` | The application code | Owned by root, readable by `app` — the app can't modify itself |
| `USER app` | Everything after, and the container, runs as `app` | Least privilege |
| `EXPOSE 8000` | Documents the port | Above 1024, so non-root can bind it |
| `HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3` | Docker checks every 10 s; 3 s per try; 10 s grace at start; 3 failures → `unhealthy` | Docker knows if the app really works |
| `CMD ["python", "-c", "…urlopen('http://127.0.0.1:8000/health'…)"]` | The check: call `/health` | Python, because Alpine has no `curl` |
| `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]` | Starts the API | Exec form; `0.0.0.0` so the published port reaches it |

### 2.4 Keep secrets and Compose files out of the image
```bash
printf '.env\n.env.example\ncompose.yaml\n' >> .dockerignore
cat .dockerignore
```
| Command | Meaning |
|---|---|
| `printf '…' >> .dockerignore` | `>>` appends 3 lines: never send `.env` (passwords) or Compose files to the builder |
| `cat .dockerignore` | Check: the 6 Day 6 lines + 3 new ones |

### 2.5 Build and prove it
```bash
docker build -t capstone:0.2 .
docker images capstone
docker run --rm capstone:0.2 id
docker run -d --name cap2 -p 8088:8000 capstone:0.2
sleep 15
docker ps --filter name=cap2 --format '{{.Names}}  {{.Status}}'
curl -s localhost:8088/health
docker rm -f cap2
```
| Command | Meaning / result |
|---|---|
| `docker build -t capstone:0.2 .` | Build the new image |
| `docker images capstone` | `0.2` **117 MB** next to `0.1` ~202 MB ✅ |
| `docker run --rm capstone:0.2 id` | `uid=10001(app) gid=10001(app)` ✅ non-root |
| `docker run -d --name cap2 -p 8088:8000 capstone:0.2` | Run it in the background |
| `sleep 15` | Let the first health checks run |
| `docker ps --filter name=cap2 --format …` | `Up … (healthy)` — the `HEALTHCHECK` works |
| `curl -s localhost:8088/health` | `{"status":"ok"}` |
| `docker rm -f cap2` | Clean up before Compose uses port 8088 |

### 2.6 Where the size comes from (optional)
```bash
docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E 'python|capstone'
docker history capstone:0.2 --format 'table {{.Size}}\t{{.CreatedBy}}' | head -12
docker run --rm capstone:0.2 sh -c 'du -sh /opt/venv /usr/local/lib/python3.12 2>/dev/null'
```
| Command | Shows |
|---|---|
| `docker images … \| grep …` | Base images next to `0.1` and `0.2` |
| `docker history capstone:0.2 …` | Size of each layer: base, `/opt/venv`, code |
| `du -sh /opt/venv /usr/local/lib/python3.12` | Your packages vs Python's own library (part of the base) |

---

## Part 3 — `compose.yaml`: app + Postgres, config as env vars

### 3.1 The config
```bash
cat > .env <<'EOF'
POSTGRES_USER=app
POSTGRES_PASSWORD=change-me-locally
POSTGRES_DB=app
APP_ENV=dev
EOF

cat > .env.example <<'EOF'
# Copy to .env and set real values:  cp .env.example .env
POSTGRES_USER=app
POSTGRES_PASSWORD=change-me
POSTGRES_DB=app
APP_ENV=dev
EOF

echo ".env" >> .gitignore
cat .gitignore
ls -la .env .env.example
```
| Command / line | Meaning |
|---|---|
| `.env` | The real config (with the password); Compose reads it automatically from this folder |
| `POSTGRES_USER / PASSWORD / DB` | User, password and database the Postgres image creates on first start |
| `APP_ENV=dev` | Which environment this is |
| `.env.example` | Same keys, dummy values — committed so others know what to set |
| `echo ".env" >> .gitignore` | Never commit `.env` |
| `ls -la .env .env.example` | **Both must exist** — without `.env`, Compose warns "variable is not set" and Postgres refuses to start |

### 3.2 `compose.yaml`
```bash
cat > compose.yaml <<'EOF'
name: capstone

services:
  db:
    image: postgres:16-alpine
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
    restart: unless-stopped

  app:
    build: .
    image: capstone:0.2
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      APP_ENV: ${APP_ENV:-dev}
    ports:
      - "8088:8000"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

volumes:
  pgdata:
EOF
```
| Line | Meaning |
|---|---|
| `name: capstone` | Fixed project name — no clash with other folders |
| `image: postgres:16-alpine` | Official Postgres 16, Alpine variant |
| `POSTGRES_USER: ${POSTGRES_USER}` | Filled from `.env` — no password in this file |
| `pgdata:/var/lib/postgresql/data` | Database files on a named volume (survives `down`) |
| `pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}` | Postgres's own readiness check; `$$` = literal `$` for the container's shell |
| `interval / timeout / retries` | Every 5 s, 3 s each, unhealthy after 10 failures |
| `restart: unless-stopped` | Restart after a crash or reboot, unless stopped by you |
| `build: .` + `image: capstone:0.2` | Build this Dockerfile and tag the result |
| `DATABASE_URL: postgresql://…@db:5432/…` | Config as an env var; host `db` = the service name |
| `APP_ENV: ${APP_ENV:-dev}` | From `.env`, or `dev` if unset (`:-` = default) |
| `ports: "8088:8000"` | Only the app is published; Postgres has no `ports:` — internal only |
| `depends_on: db: condition: service_healthy` | App starts after Postgres is ready |
| Top-level `volumes: pgdata:` | Declares the named volume |

### 3.3 Start and prove
```bash
docker compose config --services
docker compose config | grep -E 'DATABASE_URL|APP_ENV|condition'
docker compose up -d --build
docker compose ps
curl -s localhost:8088/health
curl -s localhost:8088/items
docker compose exec app id
docker compose exec app sh -c 'env | grep -E "^(DATABASE_URL|APP_ENV)="'
docker compose exec db psql -U app -d app -c 'SELECT version();'
docker compose logs app --tail 5
```
| Command | Meaning / result |
|---|---|
| `docker compose config --services` | Valid file → `db`, `app` |
| `docker compose config \| grep …` | `${…}` filled from `.env` (shows the password — don't share it) |
| `docker compose up -d --build` | Build `capstone:0.2`, create network + volume, start `db` → wait healthy → start `app` |
| `docker compose ps` | `app Up (healthy) 0.0.0.0:8088->8000` · `db Up (healthy) 5432/tcp` |
| `curl …/health`, `…/items` | `{"status":"ok"}` and the 2 items |
| `docker compose exec app id` | `uid=10001(app)` — non-root in the stack |
| `docker compose exec app sh -c 'env \| grep …'` | `DATABASE_URL=postgresql://app:…@db:5432/app`, `APP_ENV=dev` — config arrived as env vars |
| `docker compose exec db psql … 'SELECT version();'` | `PostgreSQL 16…` — the database runs |
| `docker compose logs app --tail 5` | The last 5 log lines (stdout) |

### 3.4 Stop and start
```bash
docker compose down
docker volume ls | grep capstone
docker compose up -d
docker compose ps
```
| Command | Meaning |
|---|---|
| `docker compose down` | Remove the containers and the network |
| `docker volume ls \| grep capstone` | `capstone_pgdata` still exists — data kept |
| `docker compose up -d` → `ps` | Both back and healthy, no rebuild needed |
| (`docker compose stop` / `start`) | Alternative: stop without removing the containers |

---

## Part 4 — README, commit, PR

### 4.1 README
`day07/README.md` was rewritten with: endpoints, how to run the stack and the tests, the configuration table, the Dockerfile and `compose.yaml` line by line, and an image-facts table (v0.1 vs v0.2).
```bash
cat > README.md <<'EOF'
… (see day07/README.md) …
EOF
head -5 README.md
```
| Command | Meaning |
|---|---|
| `cat > README.md <<'EOF'` | Replace the README; quoted `'EOF'` keeps the inner code blocks literal |
| `head -5 README.md` | Check the beginning |

### 4.2 `.env` stays out of Git
```bash
git check-ignore -v .env
cd ~/Devops-Sprint-Wisam
git status -s
```
| Command | Meaning / result |
|---|---|
| `git check-ignore -v .env` | `.gitignore:4:.env .env` — ignored ✅ (nothing printed = stop) |
| `cd ~/Devops-Sprint-Wisam` | Back to the **repo root** — the paths in 4.3 start with `day07/` |
| `git status -s` | `?? day07/` (plus old practice files) — **`.env` must not be listed** |

### 4.3 Stage and check
```bash
git add day07/
git diff --cached --name-only
git diff --cached | grep -n 'change-me-locally' || echo "real password not staged"
```
| Command | Meaning |
|---|---|
| `git add day07/` | Stage the folder; `.gitignore` keeps `.env` out |
| `git diff --cached --name-only` | The files to commit — **no `day07/.env`** |
| `grep -n 'change-me-locally' \|\| echo …` | The real password must not be staged → `real password not staged` |

> **Path tip:** paths are relative to where you are. From the repo root use `day07/Dockerfile`; from inside `day07/` use `Dockerfile`. Mixing them gives `pathspec … did not match any files` — and `git add` then stages **nothing**.

### 4.4 Commit, PR, review, merge
```bash
git commit -m "feat: small non-root image and Compose stack with Postgres"
git push -u origin lab/day07-compose
gh pr create --base labs --title "feat: Day 7 - non-root image under 150 MB and Compose with Postgres" \
  --body "Alpine multi-stage Dockerfile (117 MB, uid 10001, HEALTHCHECK); compose.yaml with Postgres 16; config via env vars from a git-ignored .env."
git diff --stat origin/labs...HEAD
gh pr review --comment --body "Self-review: no .env, image 117 MB non-root, stack healthy."
gh pr merge --squash --delete-branch
git switch labs && git pull
git log --oneline -2
```
| Command | Meaning |
|---|---|
| `git commit -m "feat: …"` | Conventional Commit for a new feature |
| `git push -u origin lab/day07-compose` | Upload the branch (only `main` and `labs` are protected) |
| `gh pr create --base labs …` | PR into `labs` with an explicit title |
| `git diff --stat origin/labs...HEAD` | Self-review: only `day07/` files |
| `gh pr review --comment` | Record the review |
| `gh pr merge --squash --delete-branch` | Merge as one commit, delete the branch |
| `git log --oneline -2` | The merge commit on `labs` |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `docker: command could not be found` / `Input/output error` in WSL | Docker Desktop's engine stopped (Resource Saver) | Restart Docker Desktop, open a new WSL terminal |
| `The "POSTGRES_PASSWORD" variable is not set` + `service "app" is not running` | No `.env` in the folder → empty password → Postgres exits → app waits forever | Create `.env`, then `docker compose down -v && docker compose up -d` |
| `port is already allocated` on 8088 | An old container still holds the port | `docker ps`, then `docker rm -f <name>` |
| `container name … already in use` | Another folder with the same project name | Set `name:` in `compose.yaml` or use `-p` |
| `pathspec … did not match any files` | Path relative to the wrong folder | Check `pwd`; use paths from where you are |
| App `Exited`, `docker compose logs app` shows errors | Code or config problem | Read the log; `docker compose up -d --build` after fixing |

## Commands to remember
| Goal | Command |
|---|---|
| Build + start the stack | `docker compose up -d --build` |
| Status / health | `docker compose ps` |
| Logs | `docker compose logs -f app` |
| Inside a service | `docker compose exec app sh` |
| Stop, keep containers | `docker compose stop` → `docker compose start` |
| Remove, keep data | `docker compose down` |
| Remove everything incl. data | `docker compose down -v` |
| Image size / user | `docker images capstone` · `docker run --rm capstone:0.2 id` |
