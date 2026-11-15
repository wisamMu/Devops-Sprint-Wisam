[⬅ Back to labs](../SPRINT.md)

# Day 6 Lab — The Capstone API, Containerized

**The task (sprint plan):** Write a small Python API (FastAPI or Flask) with `/health` and `/items` endpoints and 2 pytest tests. Containerize it, run it locally, and explain each Dockerfile line in the README. **This app is your capstone.**

**Date:** 2026-11-15 · **Where:** WSL Ubuntu 24.04 + Docker Desktop (`29.6.1`) · **Cost:** $0
**Result:** merged into `git-lab` as **PR #8** (`054a540`) — folder `capstone/`, 10 files.

| Part | What | Time |
|---|---|---|
| 1 | Setup, branch, the app and the 2 tests | 20 min |
| 2 | Run the tests and the app with Python (optional) | 10 min |
| 3 | Containerize: tests in a container, `.dockerignore`, Dockerfile, build, run | 15 min |
| 4 | README that explains each Dockerfile line | 10 min |
| 5 | Commit, PR into `git-lab`, self-review, merge | 10 min |

**Final layout**
```text
capstone/
├── .dockerignore          what stays out of the image
├── .gitignore             what stays out of Git
├── Dockerfile             how the image is built
├── README.md              endpoints, how to run, Dockerfile line by line
├── app/
│   ├── __init__.py        makes app/ a Python package
│   └── main.py            the FastAPI application
├── pytest.ini             lets tests import app/
├── requirements.txt       runtime dependencies (go into the image)
├── requirements-dev.txt   + test tools (stay out of the image)
└── tests/
    └── test_main.py       the 2 tests
```

---

## Part 1 — Setup, the app and the tests

### 1.1 Prerequisites
```bash
docker version --format '{{.Server.Version}}'
sudo apt update && sudo apt install -y python3.12-venv
```
| Command | Meaning |
|---|---|
| `docker version --format '{{.Server.Version}}'` | Prints the engine version only if Docker Desktop is running; "failed to connect" = start Docker Desktop first |
| `sudo apt update` | Refresh Ubuntu's package list |
| `sudo apt install -y python3.12-venv` | Install Python's virtual-environment tool and pip (missing in this WSL). `-y` answers "yes" |

### 1.2 Branch and folders
```bash
cd ~/Devops-Sprint-Wisam
git switch git-lab && git pull
git status -s
git switch -c lab/day06-capstone
mkdir -p capstone/app capstone/tests
cd capstone
```
| Command | Meaning |
|---|---|
| `git switch git-lab && git pull` | Start from the latest labs branch |
| `git status -s` | Short status; old untracked practice files (`err.txt`, `note.txt`) are left alone |
| `git switch -c lab/day06-capstone` | Create and switch to a topic branch for this lab |
| `mkdir -p capstone/app capstone/tests` | Create the folders; `-p` creates parents and doesn't fail if they exist |
| `cd capstone` | Work inside the new folder |

### 1.3 Dependencies
```bash
cat > requirements.txt <<'EOF'
fastapi==0.163.1
uvicorn==0.54.0
EOF

cat > requirements-dev.txt <<'EOF'
-r requirements.txt
pytest==9.2.0
httpx2==2.16.0
EOF
```
| Part | Meaning |
|---|---|
| `cat > file <<'EOF' … EOF` | Heredoc: write the lines between the markers into the file |
| `requirements.txt` | Packages the app needs **to run** — installed in the image |
| `fastapi==0.163.1` | The web framework; `==` pins the exact version so builds repeat |
| `uvicorn==0.54.0` | The ASGI server that runs a FastAPI app |
| `requirements-dev.txt` | Packages needed **for development/testing** — not in the image |
| `-r requirements.txt` | Include everything from `requirements.txt` too |
| `pytest==9.2.0` | The test runner |
| `httpx2==2.16.0` | HTTP client used by FastAPI's `TestClient` (newer Starlette prefers it over `httpx`; `httpx` gave a deprecation warning) |

### 1.4 The application — `app/main.py`
```bash
touch app/__init__.py
cat > app/main.py <<'EOF'
"""Sprint Items API - the DevOps sprint capstone app."""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Sprint Items API", version="0.1.0")


class Item(BaseModel):
    name: str
    price: float


ITEMS: dict[int, Item] = {
    1: Item(name="laptop stand", price=25.0),
    2: Item(name="usb-c cable", price=9.5),
}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/items")
def list_items() -> list[dict]:
    return [{"id": item_id, **item.model_dump()} for item_id, item in ITEMS.items()]


@app.get("/items/{item_id}")
def get_item(item_id: int) -> dict:
    if item_id not in ITEMS:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"id": item_id, **ITEMS[item_id].model_dump()}


@app.post("/items", status_code=201)
def create_item(item: Item) -> dict:
    item_id = max(ITEMS, default=0) + 1
    ITEMS[item_id] = item
    return {"id": item_id, **item.model_dump()}
EOF
```
| Line(s) | Meaning |
|---|---|
| `touch app/__init__.py` | Create an empty file that makes `app/` a Python **package**, so `from app.main import app` works |
| `from fastapi import FastAPI, HTTPException` | The framework class and the exception type for HTTP errors |
| `from pydantic import BaseModel` | Pydantic validates request data; a wrong type → automatic `422` |
| `app = FastAPI(title=…, version=…)` | The application object; uvicorn runs it as `app.main:app` (file `app/main.py`, object `app`) |
| `class Item(BaseModel)` | The data shape: `name` is text, `price` is a number |
| `ITEMS: dict[int, Item] = {…}` | An in-memory "database" with two items; it resets on restart (Postgres comes on Day 7) |
| `@app.get("/health")` | Route: `GET /health` runs the function below — used by health checks |
| `return {"status": "ok"}` | FastAPI turns the dict into JSON |
| `@app.get("/items")` | `GET /items` → the list of items |
| `{"id": item_id, **item.model_dump()}` | `model_dump()` turns the item into a dict; `**` merges it with the id |
| `@app.get("/items/{item_id}")` | `{item_id}` is read from the URL and converted to `int` |
| `raise HTTPException(status_code=404, …)` | Unknown id → HTTP 404 `{"detail":"Item not found"}` |
| `@app.post("/items", status_code=201)` | `POST /items` with a JSON body creates an item → `201 Created` |
| `max(ITEMS, default=0) + 1` | The next id (`default=0` handles an empty dict) |

### 1.5 The two tests — `tests/test_main.py`
```bash
cat > tests/test_main.py <<'EOF'
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_items_returns_a_list():
    response = client.get("/items")
    assert response.status_code == 200
    items = response.json()
    assert isinstance(items, list)
    assert {"id", "name", "price"} <= items[0].keys()
EOF

cat > pytest.ini <<'EOF'
[pytest]
pythonpath = .
EOF

cat > .gitignore <<'EOF'
.venv/
__pycache__/
.pytest_cache/
EOF
```
| Line(s) | Meaning |
|---|---|
| `TestClient(app)` | Calls the app in memory — no server or port needed |
| `def test_…():` | pytest runs every function whose name starts with `test_` |
| `assert response.status_code == 200` | The test fails unless the status is 200 |
| `assert response.json() == {"status": "ok"}` | The body must be exactly this |
| `assert isinstance(items, list)` | `/items` must return a list |
| `{"id", "name", "price"} <= items[0].keys()` | Set subset: the first item has at least these fields |
| `pytest.ini` · `pythonpath = .` | Lets the tests import `app` from the `capstone/` folder |
| `.gitignore` | Keeps the virtual env and caches out of Git |

### 1.6 Check the files
```bash
find . -type f | sort
```
| Command | Meaning |
|---|---|
| `find . -type f` | List every file under the current folder |
| `\| sort` | Alphabetical order, easy to compare with the expected list |

---

## Part 2 — Run with Python (optional: shows the "without Docker" way)

### 2.1 Virtual environment
```bash
cd ~/Devops-Sprint-Wisam/capstone
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements-dev.txt
pip list | grep -iE 'fastapi|uvicorn|pytest|httpx2'
```
| Command | Meaning |
|---|---|
| `python3 -m venv .venv` | Create a private Python environment in `.venv/` |
| `source .venv/bin/activate` | Use it in this terminal (prompt starts with `(.venv)`) |
| `pip install --upgrade pip` | Update pip inside the venv |
| `pip install -r requirements-dev.txt` | Install the app's packages plus pytest and httpx2 |
| `pip list \| grep -iE …` | Show the four main packages and their versions |

### 2.2 Tests
```bash
pytest -v
sed -i 's/"status": "ok"}/"status": "broken"}/' app/main.py
pytest -q
sed -i 's/"status": "broken"}/"status": "ok"}/' app/main.py
pytest -q
```
| Command | Meaning |
|---|---|
| `pytest -v` | Run the tests, one line each → `2 passed` |
| `sed -i 's/…ok…/…broken…/'` | Break `/health` on purpose |
| `pytest -q` | Quiet run → `1 failed, 1 passed`: proof the test really checks something |
| Second `sed` + `pytest -q` | Restore it → `2 passed` |

### 2.3 Run the server locally
```bash
uvicorn app.main:app --reload --port 8000
```
| Part | Meaning |
|---|---|
| `uvicorn` | The server |
| `app.main:app` | Module `app/main.py`, object `app` |
| `--reload` | Restart automatically when a file changes (development only) |
| `--port 8000` | Listen on port 8000 (default host `127.0.0.1`) |

```bash
curl -s localhost:8000/health
curl -s localhost:8000/items
curl -s localhost:8000/items/1
curl -s -i localhost:8000/items/99 | head -1
curl -s -X POST localhost:8000/items -H 'Content-Type: application/json' -d '{"name":"mouse","price":12.5}'
curl -s -i -X POST localhost:8000/items -H 'Content-Type: application/json' -d '{"name":"bad","price":"abc"}' | head -1
```
| Command | Meaning / expected |
|---|---|
| `curl -s` | Make a request, silently (no progress bar) |
| `/health` | `{"status":"ok"}` |
| `/items`, `/items/1` | The list, one item |
| `-i … \| head -1` | `-i` includes headers; `head -1` keeps the status line → `HTTP/1.1 404 Not Found` |
| `-X POST -H 'Content-Type: application/json' -d '{…}'` | Send JSON → `{"id":3,…}` (201) |
| `"price":"abc"` | `HTTP/1.1 422 Unprocessable Entity` — Pydantic validation |
| `http://localhost:8000/docs` | Interactive API page generated by FastAPI |
| `Ctrl+C` | Stop the server |

---

## Part 3 — Containerize

### 3.1 Run the tests inside a container (no local Python needed)
```bash
cd ~/Devops-Sprint-Wisam/capstone
docker run --rm -v "$PWD":/src -w /src python:3.12-slim \
  sh -c "pip install -q --root-user-action=ignore -r requirements-dev.txt && pytest -v -p no:cacheprovider"
```
| Part | Meaning |
|---|---|
| `docker run --rm` | A throwaway container, deleted when it finishes |
| `-v "$PWD":/src` | Bind-mount the `capstone/` folder into the container at `/src` |
| `-w /src` | Work in `/src` inside the container |
| `python:3.12-slim` | Official image that already has Python 3.12 |
| `sh -c "… && …"` | Run two commands: install dev packages, then run the tests |
| `-q` | Quiet pip output |
| `--root-user-action=ignore` | Silence pip's "running as root" warning (normal in a container) |
| `-p no:cacheprovider` | Don't create `.pytest_cache` in your folder (it would be owned by root) |
| **Result** | `2 passed` — tested in Python 3.12 without installing Python on the laptop |

### 3.2 `.dockerignore`
```bash
cat > .dockerignore <<'EOF'
.venv/
__pycache__/
.pytest_cache/
.git/
tests/
requirements-dev.txt
EOF
```
| Line | Why it stays out of the build context |
|---|---|
| `.venv/` | Local virtual env: big and built for this machine |
| `__pycache__/`, `.pytest_cache/` | Generated caches |
| `.git/` | History isn't needed to run the app (and may hold secrets) |
| `tests/`, `requirements-dev.txt` | Tests and test tools don't belong in the production image |

### 3.3 The Dockerfile
```bash
cat > Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
```
*(Each line is explained in Part 4 — the README deliverable.)*

### 3.4 Build
```bash
docker build -t capstone:0.1 .
docker images capstone
docker history capstone:0.1
```
| Command | Meaning |
|---|---|
| `docker build -t capstone:0.1 .` | Build image `capstone`, tag `0.1`, using the current folder as the build context |
| `docker images capstone` | Show the image → ~**202 MB** (Day 7 goal: under 150 MB) |
| `docker history capstone:0.1` | One line per layer: the big `pip install` layer, the small `COPY app/` layer |

### 3.5 Run and test the container
```bash
docker run -d --name capstone -p 8088:8000 capstone:0.1
docker ps
sleep 2
curl -s localhost:8088/health
curl -s localhost:8088/items
curl -s -i localhost:8088/items/99 | head -1
curl -s -X POST localhost:8088/items -H 'Content-Type: application/json' -d '{"name":"mouse","price":12.5}'
docker logs capstone
```
| Command | Meaning / expected |
|---|---|
| `-d` | Run in the background |
| `--name capstone` | A readable name |
| `-p 8088:8000` | Host port **8088** → container port **8000** (8080 is reserved by Windows on this laptop) |
| `docker ps` | `Up`, ports `0.0.0.0:8088->8000/tcp` |
| `sleep 2` | Give uvicorn a moment to start |
| `curl …/health` | `{"status":"ok"}` — served from inside the container |
| `curl …/items/99` | `HTTP/1.1 404 Not Found` |
| `curl -X POST …` | `{"id":3,"name":"mouse","price":12.5}` |
| `docker logs capstone` | uvicorn's access log, one line per request (thanks to `PYTHONUNBUFFERED=1`) |
| `http://localhost:8088/docs` | The interactive docs, served by the container |

### 3.6 Look inside and prove it's disposable
```bash
docker exec capstone ls /app
docker exec capstone ls /app/app
docker rm -f capstone
docker run -d --name capstone -p 8088:8000 capstone:0.1
sleep 2 && curl -s localhost:8088/items
```
| Command | What it proves |
|---|---|
| `docker exec capstone ls /app` | Only `app/` and `requirements.txt` — no tests, no `.venv` (`.dockerignore` worked) |
| `docker exec capstone ls /app/app` | The application code |
| `docker rm -f capstone` | Stop and delete the container |
| Run again + `/items` | The `mouse` item is gone: in-memory data dies with the container → Day 7 adds Postgres on a volume |

### 3.7 See the build cache with your own app
```bash
sed -i 's/version="0.1.0"/version="0.1.1"/' app/main.py
docker build -t capstone:0.1.1 .
docker rm -f capstone
```
| Command | Meaning |
|---|---|
| `sed -i 's/…0.1.0…/…0.1.1…/'` | Change one line of code |
| `docker build -t capstone:0.1.1 .` | Rebuild: `FROM`, `WORKDIR`, `ENV`, `COPY requirements.txt`, `RUN pip install` are **CACHED**; only `COPY app/` reruns (~2 s) |
| `docker rm -f capstone` | Clean up |

### uvicorn with and without Docker
| | Without Docker | With Docker |
|---|---|---|
| You type | `uvicorn app.main:app --reload --port 8000` | `docker run -d -p 8088:8000 capstone:0.1` |
| Who starts uvicorn | You | The container, from the Dockerfile `CMD` |
| Where it runs | Laptop Python in `.venv` | Python 3.12 inside the container |
| Needs installed | Python, venv, packages | Only Docker |
| Flags | `--reload` (dev), host `127.0.0.1` | `--host 0.0.0.0` (reachable through `-p`), no `--reload` |

Both can run at once: **the port decides who answers** — `localhost:8000` → local uvicorn, `localhost:8088` → container. Only **host** ports must be unique; port 8000 inside the container doesn't clash with port 8000 on the laptop.

---

## Part 4 — README with each Dockerfile line explained

```bash
cd ~/Devops-Sprint-Wisam/capstone
cat > README.md <<'EOF'
… (endpoints, how to run, how to test, the Dockerfile table below, .dockerignore, image facts) …
EOF
head -20 README.md
find . -type f -not -path './.venv/*' | sort
```
| Command | Meaning |
|---|---|
| `cat > README.md <<'EOF'` | Write the README; quoted `'EOF'` keeps `$PWD` and inner code blocks literal |
| `head -20 README.md` | Check the beginning of the file |
| `find . -type f -not -path './.venv/*' \| sort` | List the project files, skipping the virtual env → the 10 expected files |

**The Dockerfile, line by line (as written in the README)**

| Line | What it does | Why |
|---|---|---|
| `FROM python:3.12-slim` | Starts from the official Python 3.12 slim image | Python is preinstalled; `slim` drops compilers/docs → smaller, safer; pinned tag → repeatable |
| `WORKDIR /app` | Creates `/app` and makes it the working folder | Later paths are relative to `/app`; clearer than `cd` |
| `ENV PYTHONDONTWRITEBYTECODE=1` | Python writes no `.pyc` files | Useless in a container; fewer files |
| `ENV PYTHONUNBUFFERED=1` | Output isn't buffered | Logs appear in `docker logs` immediately |
| `COPY requirements.txt .` | Copies only the dependency list | Dependencies rarely change → the next layer stays cached |
| `RUN pip install --no-cache-dir -r requirements.txt` | Installs FastAPI and uvicorn at build time | `--no-cache-dir` keeps pip's cache out of the layer → smaller image |
| `COPY app/ ./app/` | Copies the application code | Last, because code changes most → a code edit rebuilds only this layer |
| `EXPOSE 8000` | Documents the container port | Doesn't publish it; `docker run -p 8088:8000` does |
| `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]` | Command run at every container start | Exec form → `docker stop` reaches uvicorn; `0.0.0.0` → reachable through the published port |

**Image facts:** base `python:3.12-slim` · size ~202 MB · runs as root (non-root on Day 7) · port 8000.

---

## Part 5 — Commit, PR, self-review, merge

### 5.1 What will be committed
```bash
cd ~/Devops-Sprint-Wisam
git branch --show-current
git status -s
```
| Command | Meaning |
|---|---|
| `git branch --show-current` | Confirm the branch → `lab/day06-capstone` |
| `git status -s` | `?? capstone/` plus old practice files that stay out |

### 5.2 Stage only the capstone
```bash
git add capstone/
git status -s
git diff --cached --name-only
```
| Command | Meaning |
|---|---|
| `git add capstone/` | Stage the folder; `capstone/.gitignore` keeps `.venv/` and caches out |
| `git diff --cached --name-only` | List what's staged → exactly the 10 files, no `.venv` |

### 5.3 Commit and push
```bash
git commit -m "feat: add capstone FastAPI app with tests and Dockerfile"
git push -u origin lab/day06-capstone
```
| Part | Meaning |
|---|---|
| `feat:` | Conventional Commits type for a new feature |
| `git push -u origin lab/day06-capstone` | Upload the branch (allowed — only `main`/`git-lab` are protected) and track it |

### 5.4 Open the PR
```bash
gh pr create --base git-lab \
  --title "feat: Day 6 capstone - FastAPI app, tests and Dockerfile" \
  --body "Day 6 lab: FastAPI app with /health and /items, 2 pytest tests, Dockerfile, .dockerignore, README explaining each Dockerfile line."
```
| Part | Meaning |
|---|---|
| `--base git-lab` | Target the protected labs branch |
| `--title` / `--body` | Explicit title and description |

### 5.5 Self-review
```bash
git diff --stat origin/git-lab...HEAD
git diff origin/git-lab...HEAD | grep -nE '\b[0-9]{12}\b|AKIA[0-9A-Z]{16}|aws_secret_access_key|password' || echo "no secrets found"
gh pr view --web
gh pr review --comment --body "Self-review: 10 files under capstone/, tests pass in a container, no secrets."
```
| Command | Meaning |
|---|---|
| `git diff --stat A...B` | Files changed by the branch since it left `git-lab` → only `capstone/…` |
| `grep -nE '…' \|\| echo` | Scan for an account ID, access key, secret key or password |
| `gh pr view --web` | Read the **Files changed** tab in the browser |
| `gh pr review --comment` | Record the self-review (you can't approve your own PR) |

### 5.6 Merge and verify
```bash
gh pr merge --squash --delete-branch
git switch git-lab && git pull
git log --oneline -2
ls capstone
```
| Command | Meaning |
|---|---|
| `gh pr merge --squash --delete-branch` | Merge as one commit on GitHub; delete the branch on both sides |
| `git switch git-lab && git pull` | Download the merged result |
| `git log --oneline -2` | Top commit → `054a540 feat: add capstone FastAPI app with tests and Dockerfile (#8)` |
| `ls capstone` | The app is now on `git-lab` |

---

## ✅ Lab checklist
| Requirement | Where |
|---|---|
| Small Python API with `/health` and `/items` | `capstone/app/main.py` (+ `GET /items/{id}`, `POST /items`) |
| 2 pytest tests | `capstone/tests/test_main.py` — `2 passed` in `python:3.12-slim` |
| Containerized | `capstone/Dockerfile` + `.dockerignore` → image `capstone:0.1` (~202 MB) |
| Runs locally | `docker run -d -p 8088:8000 capstone:0.1` → `/health` = `{"status":"ok"}` |
| Each Dockerfile line explained | `capstone/README.md` |
| Capstone | On `git-lab` via PR #8; grows on Days 7–10 |

## Commands to remember
| Goal | Command |
|---|---|
| Build | `docker build -t capstone:0.1 .` |
| Run | `docker run -d --name capstone -p 8088:8000 capstone:0.1` |
| Test the API | `curl -s localhost:8088/health` |
| Logs | `docker logs -f capstone` |
| Inside the container | `docker exec capstone ls /app` |
| Tests without local Python | `docker run --rm -v "$PWD":/src -w /src python:3.12-slim sh -c "pip install -q -r requirements-dev.txt && pytest -v -p no:cacheprovider"` |
| Clean up | `docker rm -f capstone` |
