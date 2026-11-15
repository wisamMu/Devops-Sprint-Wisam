[⬅ Back to index](../README.md)

# Day 6 — Containers with Docker (Week 2 · Day 1)

**Date:** 2026-11-15
**Topic:** containers — images vs containers, layers, Dockerfile, ports, volumes, environment variables
**Where:** WSL Ubuntu 24.04 + Docker Desktop (Docker Engine `29.6.1`)
**Reading:** *Docker: Get started* (docs.docker.com/get-started)
**Cost:** $0 — everything ran locally.
**Lab (later):** a small Python API with `/health` and `/items`, 2 pytest tests, containerized — the sprint capstone.

| Part | Content |
|---|---|
| 📖 Cheat sheet | Every Docker command from today, one line each |
| Sections 1–7 | Definitions with examples, and every command explained |
| Check-your-understanding answers | All 7 sections |
| Key takeaways | What to remember |

---

## 📖 Docker cheat sheet

| Goal | Command |
|---|---|
| Is the engine running? | `docker version --format '{{.Server.Version}}'` |
| Download an image | `docker pull nginx:1.27` |
| List images | `docker images` |
| Run a container (background, named, port) | `docker run -d --name web -p 8088:80 nginx:1.27` |
| Run once and delete on exit | `docker run --rm alpine:3.20 echo hi` |
| List running / all containers | `docker ps` · `docker ps -a` |
| Run a command inside | `docker exec web ls /usr/share/nginx/html` |
| Open a shell inside | `docker exec -it web sh` |
| Logs | `docker logs web` · `docker logs -f web` |
| Stop / remove / force-remove | `docker stop web` · `docker rm web` · `docker rm -f web` |
| Show published ports | `docker port web` |
| Build an image | `docker build -t myapi:0.1 .` |
| Image layers | `docker history nginx:1.27` |
| Inspect anything | `docker inspect web` · `docker image inspect nginx:1.27` |
| Volumes | `docker volume create mydata` · `docker volume ls` · `docker volume rm mydata` |
| Mount a volume / folder | `-v mydata:/data` · `-v ~/site:/usr/share/nginx/html:ro` |
| Environment variables | `-e APP_ENV=prod` · `--env-file .env` |
| Disk used by Docker | `docker system df` |
| Remove an image | `docker rmi nginx:1.27` |

---

## Section 1 — What a container is

| Term | Definition | Example |
|---|---|---|
| **"Works on my machine"** | The problem containers solve: an app depends on a language version, libraries and OS packages that differ between machines. | Python 3.12 locally, 3.9 on the server → crash |
| **Container** | A running app **packaged with everything it needs** (code, runtime, libraries), isolated from other apps but **sharing the host's kernel**. | `docker run hello-world` |
| **Virtual machine (VM)** | A whole computer emulated in software, with **its own kernel and OS**. | An EC2 instance |
| **Container vs VM** | VM: full OS, GBs, minutes to boot. Container: only app + libraries, MBs, seconds to start. | VM ≈ a house; container ≈ an apartment sharing the foundation |
| **Namespaces** | Kernel feature giving each container its own view of processes, network and files (isolation). | `ps` inside a container shows only its processes |
| **cgroups** | Kernel feature limiting a container's CPU and memory. | `docker run --memory 256m …` |
| **Docker** | The tool to build, run and share containers. | `docker version` |
| **Docker Engine (daemon)** | The background service that runs containers; the `docker` command only talks to it. | Docker Desktop runs it for WSL |
| **Docker Desktop** | The Windows/Mac app that runs the engine in a small Linux VM (`docker-desktop`) and connects WSL to it. | Must be running before any `docker` command |
| **Why DevOps cares** | The **same image** runs on a laptop, in CI and in production. | Day 8 CI builds it; Day 10 Kubernetes runs it |

```text
   VIRTUAL MACHINES                      CONTAINERS
┌──────┐ ┌──────┐ ┌──────┐        ┌──────┐ ┌──────┐ ┌──────┐
│ App  │ │ App  │ │ App  │        │ App  │ │ App  │ │ App  │
│ Libs │ │ Libs │ │ Libs │        │ Libs │ │ Libs │ │ Libs │
│Guest │ │Guest │ │Guest │        └──────┘ └──────┘ └──────┘
│  OS  │ │  OS  │ │  OS  │        ┌─────────────────────────┐
└──────┘ └──────┘ └──────┘        │      Docker Engine      │
┌─────────────────────────┐       ├─────────────────────────┤
│       Hypervisor        │       │  Host OS (one kernel)   │
├─────────────────────────┤       ├─────────────────────────┤
│        Hardware         │       │        Hardware         │
└─────────────────────────┘       └─────────────────────────┘
```

```bash
docker version --format '{{.Server.Version}}'
docker run --rm hello-world
```
| Part | Meaning |
|---|---|
| `docker version` | Shows the client and the engine (server) versions |
| `--format '{{.Server.Version}}'` | Print only the engine version — a quick "is Docker running?" check |
| `docker run --rm hello-world` | Download a tiny test image, run it, print a greeting; `--rm` deletes the container afterwards |

---

## Section 2 — Images vs containers

| Term | Definition | Example |
|---|---|---|
| **Image** | A **read-only template**: the files and settings needed to run an app. Built once, shared many times. | `python:3.12-slim`, `nginx:1.27` |
| **Container** | A **running (or stopped) instance** of an image, with a thin **writable layer** on top. | `docker run nginx` → a new container |
| **Analogy** | Image = a **class** (recipe). Container = an **object** (the dish). | One `nginx` image → 3 containers |
| **Tag** | A version label; `latest` is used if omitted. **Pin versions** so builds repeat. | `python:3.12-slim` |
| **Registry** | A server storing images. **Docker Hub** is public; **ECR** is AWS's (Day 9). | `docker pull nginx:1.27` |
| **Image ID / digest** | A content hash: same digest = exactly the same image. | `docker images --digests` |
| **Lifecycle** | created → **running** → stopped (exited) → removed. Stop keeps the container's files; remove deletes them. | `docker stop` · `docker rm` |
| **Ephemeral** | Containers are disposable: delete and recreate from the image. Data to keep goes in a **volume**. | `docker run --rm …` |

```bash
docker pull nginx:1.27
docker images
docker run -d --name web1 nginx:1.27
docker run -d --name web2 nginx:1.27
docker ps
docker exec web1 sh -c 'echo hi > /tmp/x'
docker exec web2 ls /tmp
docker stop web1 web2 && docker rm web1 web2
docker ps -a
docker images
```
| Part | Meaning |
|---|---|
| `docker pull nginx:1.27` | Download the image `nginx`, tag `1.27`, from Docker Hub |
| `docker images` | List the images stored locally (name, tag, ID, size) |
| `docker run` | Create **and** start a container from an image |
| `-d` | Detached: run in the background and give the terminal back |
| `--name web1` | A readable name instead of a random one (`blissful_jepsen`) |
| `docker ps` | List **running** containers |
| `docker ps -a` | List **all** containers, including stopped ones |
| `docker exec web1 <cmd>` | Run a command **inside** an already-running container |
| `sh -c '…'` | Run a small shell command line inside it |
| `docker exec web2 ls /tmp` | Proves web2 doesn't have web1's file — **each container has its own writable layer** |
| `docker stop` | Send SIGTERM, then SIGKILL after 10 s: the container stops but still exists |
| `docker rm` | Delete a stopped container (the image stays) |

---

## Section 3 — Layers and the build cache

| Term | Definition | Example |
|---|---|---|
| **Layer** | An image is a **stack of read-only layers**; each file-changing instruction (`FROM`, `RUN`, `COPY`, `ADD`) adds one. | `docker history nginx:1.27` |
| **Union filesystem** | The layers are stacked and shown as **one** filesystem; upper layers override lower ones. | One `/`, built from many layers |
| **Container layer** | The thin **writable** layer `docker run` adds; it's deleted with the container. | The `/tmp/x` written in `web1` |
| **Layer sharing** | Identical layers are **stored once** and shared between images. | Two images `FROM python:3.12-slim` share its base |
| **Build cache** | On rebuild, Docker **reuses** a layer if its instruction and inputs didn't change. | `CACHED [2/5] …` |
| **Cache invalidation** | When one layer changes, **every layer after it** is rebuilt. | Change step 3 → steps 3, 4, 5 rebuild |
| **Ordering rule** | Rarely-changing things first (base, dependencies), often-changing last (code). | `COPY requirements.txt` + install **before** `COPY . .` |
| **Deleting doesn't shrink** | A file added in one layer and removed in a later one **stays in the image**. | Create and delete in the **same** `RUN` |

```dockerfile
# ❌ any code change re-installs every dependency
COPY . .
RUN pip install -r requirements.txt

# ✅ dependencies cached; only the last COPY reruns on a code change
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
```

```bash
docker history nginx:1.27
docker image inspect nginx:1.27 --format '{{len .RootFS.Layers}} layers'
docker system df
```
| Part | Meaning |
|---|---|
| `docker history <image>` | Every layer, its size and the instruction that created it |
| `docker image inspect` | Full JSON details of an image |
| `--format '{{len .RootFS.Layers}} layers'` | A Go template: count the image's layers |
| `docker system df` | Disk used by images, containers, volumes and the build cache |

### Hands-on: the cache at work (real results)
```bash
mkdir -p ~/practice/day6-layers && cd ~/practice/day6-layers
echo "flask==3.0.3" > deps.txt
echo "version 1" > app.txt
cat > Dockerfile <<'EOF'
FROM alpine:3.20
WORKDIR /app
COPY deps.txt .
RUN echo "installing dependencies…" && sleep 5
COPY app.txt .
CMD ["cat", "/app/app.txt"]
EOF
docker build -t layers:v1 .
docker build -t layers:v1 .
echo "version 2" > app.txt && docker build -t layers:v2 .
echo "flask==3.1.0" > deps.txt && docker build -t layers:v3 .
docker run --rm layers:v2
```
| Part | Meaning |
|---|---|
| `cat > Dockerfile <<'EOF'` | Write the Dockerfile with a heredoc |
| `sleep 5` | Pretends to be a slow dependency install, so the cache is visible |
| `docker build -t layers:v1 .` | Build an image named `layers`, tag `v1`, from the Dockerfile in `.` (the build context) |

| Build | What changed | Result |
|---|---|---|
| 1 | Everything new | 13 s |
| 2 | Nothing | **2 s** — every step `CACHED` |
| 3 | `app.txt` (code) | **3 s** — only the last layer rebuilt |
| 4 | `deps.txt` (dependencies) | **11 s** — the install and everything after it rebuilt |

```bash
printf 'FROM alpine:3.20\nRUN dd if=/dev/zero of=/big.bin bs=1M count=50\nRUN rm /big.bin\n' > Dockerfile.bad
printf 'FROM alpine:3.20\nRUN dd if=/dev/zero of=/big.bin bs=1M count=50 && rm /big.bin\n' > Dockerfile.good
docker build -q -f Dockerfile.bad  -t size:bad .
docker build -q -f Dockerfile.good -t size:good .
docker images | grep size
docker history size:bad
```
| Part | Meaning |
|---|---|
| `dd if=/dev/zero of=/big.bin bs=1M count=50` | Create a 50 MB file of zeros |
| `-f Dockerfile.bad` | Use a Dockerfile with a different name |
| `-q` | Quiet: print only the image ID |
| **Result** | `size:bad` = **64.6 MB** (the 52.4 MB layer is still there under the `rm`) · `size:good` = **12.1 MB** |

---

## Section 4 — The Dockerfile

| Instruction | What it does | Example |
|---|---|---|
| **`FROM`** | The **base image**; always first. | `FROM python:3.12-slim` |
| **`WORKDIR`** | Sets (and creates) the working folder for later steps. Use it instead of `cd`. | `WORKDIR /app` |
| **`COPY`** | Copies files from the **build context** into the image. | `COPY requirements.txt .` |
| **`ADD`** | Like `COPY` plus unpacking archives and URLs. **Prefer `COPY`.** | `ADD app.tar.gz /opt/` |
| **`RUN`** | Runs a command **at build time**; the result becomes a layer. | `RUN pip install --no-cache-dir -r requirements.txt` |
| **`ENV`** | An environment variable for the build **and** at runtime. | `ENV PYTHONUNBUFFERED=1` |
| **`ARG`** | A variable for **build time only** (`--build-arg`). | `ARG APP_VERSION=dev` |
| **`EXPOSE`** | **Documents** the app's port; it does **not** publish it. | `EXPOSE 8000` |
| **`USER`** | Run later steps and the container **as this user**, not root. | `USER appuser` |
| **`CMD`** | Default command at **container start**; overridable at `docker run`. | `CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]` |
| **`ENTRYPOINT`** | The fixed program; `CMD` becomes its default arguments. | `ENTRYPOINT ["python"]` + `CMD ["app.py"]` |
| **`HEALTHCHECK`** | A command Docker runs to mark the container healthy/unhealthy. | `HEALTHCHECK CMD curl -f http://localhost:8000/health \|\| exit 1` |
| **`LABEL`** | Metadata (owner, version, source). | `LABEL org.opencontainers.image.source="…"` |
| **Build context** | The folder sent to the builder (the `.` in `docker build .`); `COPY` can only see files in it. | `docker build -t myapi .` |
| **`.dockerignore`** | Files to leave out of the build context (`.git`, `.venv`, `__pycache__`) — Day 7. | `echo .venv >> .dockerignore` |

| Pair | Difference |
|---|---|
| **`RUN` vs `CMD`** | `RUN` happens **once, at build**. `CMD` happens **every time a container starts**. |
| **`CMD` vs `ENTRYPOINT`** | `docker run img other-cmd` **replaces** `CMD`; `ENTRYPOINT` stays and receives the extra words as arguments. |
| **`COPY` vs `ADD`** | `COPY` is predictable; `ADD` has hidden behaviours. |
| **`ENV` vs `ARG`** | `ENV` lives on in the container; `ARG` exists only during the build. |
| **Exec vs shell form** | `CMD ["uvicorn", "main:app"]` gets stop signals properly; `CMD uvicorn main:app` runs under `sh`, which can swallow `docker stop`. **Use exec form.** |

**The shape of the Day 6 lab's Dockerfile**
```dockerfile
FROM python:3.12-slim                              # small official Python base image
WORKDIR /app                                       # all paths below are relative to /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1   # no .pyc files; logs appear immediately
COPY requirements.txt .                            # dependencies first, for the cache
RUN pip install --no-cache-dir -r requirements.txt # install them (no pip cache in the layer)
COPY . .                                           # then the code, which changes most often
EXPOSE 8000                                        # documents the app's port
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]   # start the API on all interfaces
```
```bash
docker build -t myapi:0.1 .
docker run --rm -p 8088:8000 myapi:0.1
```
| Part | Meaning |
|---|---|
| `docker build -t myapi:0.1 .` | Build image `myapi`, tag `0.1`, using the current folder as the build context |
| `docker run --rm -p 8088:8000 myapi:0.1` | Run it, publish host 8088 → container 8000, delete it on exit |

---

## Section 5 — Ports

| Term | Definition | Example |
|---|---|---|
| **Container network** | Each container gets its **own private network** and IP by default. | `docker inspect -f '{{.NetworkSettings.IPAddress}}' web` |
| **Container port** | The port the app listens on **inside** the container. | nginx `80`, uvicorn `8000` |
| **Host port** | The port on **your machine** that clients connect to. | `localhost:8088` |
| **Publishing (`-p HOST:CONTAINER`)** | Forwards traffic from the host port into the container. | `-p 8088:80` |
| **`EXPOSE` vs `-p`** | `EXPOSE` documents; `-p` actually opens the path. | `EXPOSE 80` alone → unreachable |
| **Host port must be free** | Two containers can't publish the same host port (but can share a container port). | `-p 8088:80` and `-p 8081:80` |
| **Bind address** | `-p 127.0.0.1:8081:80` = only this machine; `-p 8081:80` = all interfaces. | Keep databases on `127.0.0.1` |
| **App bind address** | Inside the container the app must listen on `0.0.0.0`; on `127.0.0.1` it can't be reached from outside it. | `uvicorn --host 0.0.0.0` |
| **Container ↔ container** | On the same user-defined network, containers reach each other **by name**, no `-p` needed (Day 7 Compose). | `curl http://api:8000` |
| **`-P`** | Publish every `EXPOSE`d port on random host ports. | `docker port <name>` |

```text
 Browser ──► localhost:8088 (host) ──-p 8088:80──► container :80 (nginx, listening on 0.0.0.0)
```

```bash
docker run -d --name web -p 8088:80 nginx:1.27
curl -I http://localhost:8088
docker port web
docker run -d --name web2 -p 8088:80 nginx:1.27
docker rm -f web2
docker run -d --name web3 -p 127.0.0.1:8081:80 nginx:1.27
curl -I http://localhost:8081
docker rm -f web web3
```
| Part | Meaning |
|---|---|
| `-p 8088:80` | Publish host port 8088 → container port 80 |
| `curl -I http://localhost:8088` | Request only the headers → `HTTP/1.1 200 OK` |
| `docker port web` | Show the mapping → `80/tcp -> 0.0.0.0:8088` |
| `web2` on `8088` again | Fails: **port is already allocated** — the host port is taken by `web` |
| `docker rm -f` | Stop and remove in one step |
| `-p 127.0.0.1:8081:80` | Publish only on the loopback address: other machines can't connect |

| Symptom | Likely cause |
|---|---|
| `Connection refused` on the host port | No `-p`, wrong mapping, or the container exited (`docker ps -a`, `docker logs`) |
| `port is already allocated` / `ports are not available` | Something else holds that host port |
| `-p` correct but no answer | The app listens on `127.0.0.1` inside the container → use `0.0.0.0` |

---

## Section 6 — Volumes

| Term | Definition | Example |
|---|---|---|
| **The problem** | The writable layer is **deleted with the container**, so data written there is lost. | Remove a Postgres container → database gone |
| **Volume** | Storage **managed by Docker**, outside the container; it **survives** removal. | `docker volume create pgdata` |
| **Named volume** | A volume with a name — **best for data** (databases, uploads). | `-v pgdata:/var/lib/postgresql/data` |
| **Bind mount** | A folder **from your machine** mounted into the container; changes show both ways instantly — **best for development**. | `-v ~/myapi:/app` |
| **tmpfs mount** | Storage **in memory only**, gone when the container stops. | `--tmpfs /tmp` |
| **`-v SOURCE:TARGET[:ro]`** | A name as SOURCE = named volume; a path = bind mount. `--mount` is the long, explicit form. | `-v ./site:/usr/share/nginx/html:ro` |
| **Read-only (`:ro`)** | The container can read the mount but not change it. | `-v ./nginx.conf:/etc/nginx/nginx.conf:ro` |
| **Image vs volume** | The **image** holds the app; **volumes** hold the data — replace containers freely. | Upgrade Postgres, keep `pgdata` |
| **Volume lifecycle** | `docker rm` keeps named volumes; `docker rm -v` / `docker volume prune` delete them. | `docker volume ls` |

```text
Container (disposable)
┌─────────────────────────┐
│ /var/lib/postgresql/data│◄── named volume "pgdata"   (managed by Docker, survives rm)
│ /app                    │◄── bind mount ~/myapi      (your folder, live edits)
│ /tmp                    │◄── tmpfs                   (RAM only)
│ everything else         │    writable layer          (deleted with the container)
└─────────────────────────┘
```

```bash
docker run -d --name t1 nginx:1.27
docker exec t1 sh -c 'echo saved > /data.txt'
docker rm -f t1

docker volume create mydata
docker run --rm -v mydata:/data alpine:3.20 sh -c 'echo "hello from container 1" > /data/note.txt'
docker run --rm -v mydata:/data alpine:3.20 cat /data/note.txt
docker volume ls
docker volume inspect mydata

mkdir -p ~/practice/day6-site && echo "<h1>v1</h1>" > ~/practice/day6-site/index.html
docker run -d --name site -p 8088:80 -v ~/practice/day6-site:/usr/share/nginx/html:ro nginx:1.27
curl -s http://localhost:8088
echo "<h1>v2</h1>" > ~/practice/day6-site/index.html
curl -s http://localhost:8088
docker exec site sh -c 'echo x > /usr/share/nginx/html/x'

docker rm -f site
docker volume rm mydata
```
| Part | Meaning |
|---|---|
| `docker rm -f t1` | The file in the writable layer is gone with the container |
| `docker volume create mydata` | Create a named volume |
| `-v mydata:/data` | Mount the volume at `/data` inside the container |
| Second `docker run … cat` | A **new** container still reads the file → the volume survived |
| `docker volume inspect` | Shows where Docker keeps the volume |
| `-v ~/practice/day6-site:/usr/share/nginx/html:ro` | Bind-mount your folder as nginx's web root, read-only |
| `curl` before and after editing | `<h1>v1</h1>` → `<h1>v2</h1>` with no rebuild or restart |
| `docker exec site sh -c 'echo x > …'` | → `Read-only file system`: **`:ro` blocks writes** |
| `docker volume rm` | Delete the volume and its data |

| Use | Choose |
|---|---|
| Data to keep (database, uploads) | **Named volume** |
| Code during development | **Bind mount** |
| Injected config files | **Bind mount `:ro`** |
| Temporary / secret scratch | **tmpfs** |
| The app in production | **Neither** — bake it into the image |

---

## Section 7 — Environment variables

| Term | Definition | Example |
|---|---|---|
| **Config via environment** | The **same image** runs everywhere; only config changes, passed as environment variables. | `APP_ENV=dev` vs `prod` |
| **Build once, configure at run** | Don't bake URLs or passwords into the image. | `docker run -e DB_HOST=db.prod …` |
| **`ENV`** | A **default** in the image, overridable at run. | `ENV APP_PORT=8000` |
| **`-e` / `--env`** | Set or override one variable at `docker run`. | `-e APP_ENV=prod` |
| **`--env-file`** | Load many `KEY=value` lines from a file. | `--env-file .env` |
| **Precedence** | `-e` beats `--env-file`, which beats `ENV`. | `ENV LOG_LEVEL=info` + `-e LOG_LEVEL=debug` → `debug` |
| **Reading in code** | The app reads variables at startup with a default. | `os.getenv("APP_ENV", "dev")` |
| **`ARG` isn't runtime** | Only during the build; copy into `ENV` to keep it. | `ARG VERSION` → `ENV VERSION=$VERSION` |
| **Secrets** | Env vars are visible in `docker inspect`; never `ENV` a secret in a Dockerfile (it stays in the layers); never commit `.env`. | `.env` in `.gitignore`; AWS roles on Day 9 |
| **Twelve-Factor: config** | Config lives in the environment, not the code (Day 7). | One image → many environments |

```bash
docker run --rm -e APP_ENV=prod alpine:3.20 sh -c 'echo "env is $APP_ENV"'
printf 'APP_ENV=test\nLOG_LEVEL=debug\n' > /tmp/app.env
docker run --rm --env-file /tmp/app.env alpine:3.20 env | grep -E 'APP_ENV|LOG_LEVEL'
printf 'FROM alpine:3.20\nENV LOG_LEVEL=info\nCMD ["sh","-c","echo level=$LOG_LEVEL"]\n' > /tmp/Dockerfile.env
docker build -q -t envdemo -f /tmp/Dockerfile.env /tmp
docker run --rm envdemo
docker run --rm -e LOG_LEVEL=debug envdemo
docker image inspect envdemo --format '{{json .Config.Env}}'
docker rmi envdemo && rm /tmp/app.env /tmp/Dockerfile.env
```
| Part | Meaning |
|---|---|
| `-e APP_ENV=prod` | Set `APP_ENV` inside the container → `env is prod` |
| `--env-file /tmp/app.env` | Load `APP_ENV=test` and `LOG_LEVEL=debug` from the file |
| `env \| grep …` | Print the container's environment, filtered |
| `docker run --rm envdemo` | Uses the image's default → `level=info` |
| `-e LOG_LEVEL=debug` | Overrides it → `level=debug` |
| `--format '{{json .Config.Env}}'` | Shows variables baked into the image — anyone with the image can read them |
| `docker rmi` | Remove the image |

---

## Check-your-understanding answers

| Section | Q | Answer |
|---|---|---|
| 1 | Why do containers start in seconds? | They share the host kernel — just a process starts; a VM boots an OS. |
| 2 | 3 containers, 1 image, a file changed in one — do others see it? | No: each has its own writable layer; the image is read-only. |
| 2 | `stop` vs `rm`? | `stop` ends the process (container remains); `rm` deletes it. |
| 2 | Why pin `3.12-slim` instead of `latest`? | `latest` can change under you; pinned tags give repeatable builds. |
| 3 | One line of `app.py` changes — what rebuilds? | Only the last layer (`COPY . .`). |
| 3 | Why doesn't a separate `RUN rm` shrink the image? | The earlier layer still contains the file (64.6 MB vs 12.1 MB). |
| 3 | Shared base image disk use? | Stored once. |
| 4 | Build time vs start time? | `RUN` at build; `CMD` at every start. |
| 4 | Why `COPY requirements.txt` before `COPY . .`? | Keeps the dependency install cached. |
| 4 | `EXPOSE 8000` but `curl` fails? | `EXPOSE` only documents; publish with `-p`. |
| 4 | Why `--host 0.0.0.0`? | `127.0.0.1` inside a container is the container itself. |
| 5 | In `-p 5000:8000`, which is which? | 5000 host, 8000 container. |
| 5 | Two containers on port 80? | Inside: yes. Same host port: no. |
| 5 | Why `-p 127.0.0.1:5432:5432`? | To keep it reachable only from your machine. |
| 6 | `docker rm` with a named volume — data gone? | No, the volume survives. |
| 6 | Bind mount in production? | No: production needs a self-contained image. |
| 6 | What does `:ro` protect against? | Changes to the mounted files by bugs or attackers. |
| 7 | Why `-e DB_HOST` instead of the Dockerfile? | Same image for every environment; config at run time. |
| 7 | `ENV` vs `-e` — which wins? | `-e`. |
| 7 | Why never a password in `ENV`? | It stays in the image layers and `docker inspect`. |

---

## Key takeaways

| Topic | Remember |
|---|---|
| Container vs VM | Shares the kernel → small and fast; a VM has its own OS |
| Image vs container | Image = read-only template; container = running instance + writable layer |
| Layers | Order the Dockerfile for the cache; clean up in the **same** `RUN` |
| Dockerfile | `RUN` builds, `CMD` starts; exec form; `COPY` over `ADD`; `0.0.0.0` |
| Ports | `EXPOSE` documents, `-p HOST:CONTAINER` publishes; the host port must be free |
| Volumes | Named volume for data, bind mount for dev, `:ro` for config; never rely on the writable layer |
| Env vars | Build once, configure at run; `-e` beats `ENV`; no secrets in images |
| Before any Docker work | Docker Desktop running: `docker version --format '{{.Server.Version}}'` |
