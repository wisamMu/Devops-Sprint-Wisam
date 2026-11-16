[⬅ Back to index](../README.md)

# Day 8 — CI with GitHub Actions (Week 2 · Day 3)

**Date:** 2026-11-16
**Topic:** CI with GitHub Actions — triggers, jobs, steps, runners, secrets, caching
**Reading:** [GitHub Actions docs](https://docs.github.com/en/actions) · [Quickstart](https://docs.github.com/en/actions/get-started/quickstart) · *Understanding GitHub Actions*
**Cost:** $0 — GitHub Free includes 2,000 Actions minutes/month for private repos; without a payment method, jobs stop at the limit (no charge).
**Lab (later):** on every PR, run lint (ruff), unit tests (pytest), `docker build` and an image scan with Trivy. A failing check blocks the merge.

| Part | Content |
|---|---|
| 📖 Cheat sheet | Workflow keys and `gh` commands at a glance |
| Sections A–H | Definitions with examples; every YAML line explained |
| Check-your-understanding answers | All sections |
| Key takeaways | What to remember |

---

## 📖 Cheat sheet

### Workflow file keys
| Key | Level | Meaning | Example |
|---|---|---|---|
| `name:` | workflow | Name in the Actions tab | `name: CI` |
| `run-name:` | workflow | Title of each run | `run-name: ${{ github.actor }} testing` |
| `on:` | workflow | Trigger(s) | `on: pull_request` |
| `permissions:` | workflow / job | What `GITHUB_TOKEN` may do | `contents: read` |
| `jobs:` | workflow | The jobs | `jobs: { lint: …, test: … }` |
| `runs-on:` | job | The runner | `ubuntu-24.04` |
| `needs:` | job | Run after other jobs | `needs: [lint, test]` |
| `timeout-minutes:` | job | Kill if it hangs | `10` |
| `defaults.run.working-directory:` | job | Folder for `run:` steps | `day07` |
| `env:` | workflow / job / step | Environment variables | `APP_ENV: test` |
| `steps:` | job | The steps, in order | — |
| `uses:` | step | Run an action | `actions/checkout@v6` |
| `with:` | step | Inputs for the action | `python-version: "3.12"` |
| `run:` | step | Shell command(s) | `pytest -q` |
| `if:` | job / step | Condition | `if: always()` |

### Expressions and contexts
| Expression | Gives |
|---|---|
| `${{ github.event_name }}` | The event that triggered the run (`pull_request`) |
| `${{ github.ref }}` | The branch/ref |
| `${{ github.actor }}` | Who triggered it |
| `${{ github.repository }}` | `owner/repo` |
| `${{ github.workspace }}` | Folder where checkout puts the code |
| `${{ runner.os }}` | `Linux`, `Windows`, `macOS` |
| `${{ job.status }}` | `success`, `failure`, `cancelled` |
| `${{ secrets.NAME }}` / `${{ vars.NAME }}` | A secret / a variable |
| `${{ hashFiles('path') }}` | Fingerprint of file contents (cache keys) |

### `gh` commands
| Goal | Command |
|---|---|
| List workflows | `gh workflow list` |
| Run a `workflow_dispatch` workflow | `gh workflow run ci.yml` |
| List runs | `gh run list` |
| Watch a run live | `gh run watch` |
| Show a run's log | `gh run view <id> --log` |
| Only the failed steps' log | `gh run view <id> --log-failed` |
| PR checks | `gh pr checks` |
| Secrets | `gh secret set NAME` · `gh secret list` |
| Caches | `gh cache list` |

---

## A — What GitHub Actions is

| Term | Definition | Example |
|---|---|---|
| **GitHub Actions** | A CI/CD platform built into GitHub that runs your commands when something happens in the repo. | The **Actions** tab |
| **CI (Continuous Integration)** | Every change is automatically built and tested as soon as it's pushed. | PR opened → lint and tests run |
| **CD (Continuous Delivery/Deployment)** | What passed CI is automatically delivered or deployed. | Day 9: push to ECR · Day 13: deploy |
| **Why** | Fast feedback; same checks for everyone; nothing skipped; bad code blocked before merging. | ❌ on the PR before review |
| **Where it lives** | YAML files in `.github/workflows/` — GitHub finds them only there. | `.github/workflows/ci.yml` |
| **YAML** | The file format (`.yml` / `.yaml`); indentation matters. | `on: [push]` |
| **Workflow templates** | Ready-made starters GitHub suggests for your language. | "Python application" |
| **Results** | Actions tab → workflow → run → job → step logs; ✅/❌ checks on the PR. | "CI #3 ✅ 1m 20s" |
| **Free plan** | 2,000 minutes/month for private repos; jobs stop at the limit without a payment method. | A few minutes per PR |

```text
 push / PR (event) → GitHub reads .github/workflows/*.yml → fresh machine → your steps
                   → ✅ merge allowed · ❌ merge blocked (with required checks)
```

---

## B — The components

**An event triggers a workflow, which runs jobs on runners; each job runs its steps in order.**

| Component | Definition | Example |
|---|---|---|
| **Workflow** | One automated process, defined by one YAML file. A repo can have many. | `ci.yml`, `deploy.yml` |
| **Event** | An activity in the repo that triggers a workflow. | push, pull request, schedule, manual click |
| **Job** | A set of steps on the same runner; jobs run in parallel unless one `needs` another. | `lint`, `test`, `build-scan` |
| **Step** | One task: a shell command (`run:`) or an action (`uses:`); steps run in order and share the machine. | `run: pytest -q` |
| **Action** | A reusable, packaged step. | `actions/checkout@v6` |
| **Runner** | The machine that runs a job; each job gets its own fresh runner. | `runs-on: ubuntu-latest` |

| Relationship | Meaning |
|---|---|
| 1 workflow → many jobs | One file can define several jobs |
| 1 job → 1 runner | All its steps share one machine |
| Job ↔ job | Separate machines — nothing shared unless passed on (cache) |
| Step ↔ step (same job) | Share files and tools |
| A step fails | Non-zero exit code → job ❌ → later steps skipped |

| Action source | Example |
|---|---|
| GitHub | `actions/checkout`, `actions/setup-python`, `actions/cache` |
| Marketplace | `aquasecurity/trivy-action`, `docker/build-push-action` |
| Your own | A folder with `action.yml` |

**Pin the version** (`@v6`, not `@main`) — an unpinned action can change or be compromised.

---

## C — Triggers (`on:`)

| Event | Runs when | Use |
|---|---|---|
| **`push`** | Commits are pushed to a branch | Test on every push; deploy after merge |
| **`pull_request`** | A PR is opened, updated, or reopened | **Check every PR before merge** |
| **`workflow_dispatch`** | You click **Run workflow** (or `gh workflow run`) | Manual runs |
| **`schedule`** | On a cron timer (UTC) | Nightly scans |
| `release`, `issues`, … | Other repo activity | Publish on release |

```yaml
on: push                          # one event
```
```yaml
on: [push, pull_request]          # a list
```
```yaml
on:
  pull_request:
    branches: [labs]              # PRs that target labs
    paths: ["day07/**"]           # only if files under day07/ changed
  push:
    branches: [labs]
  workflow_dispatch:              # manual "Run workflow" button
  schedule:
    - cron: "0 3 * * *"           # daily 03:00 UTC
```
| Key | Meaning |
|---|---|
| `branches: [labs]` | `pull_request`: the **target** branch · `push`: the branch pushed to |
| `branches-ignore:` | All branches except these |
| `paths: ["day07/**"]` | Run only if a changed file matches (`**` = any depth) |
| `paths-ignore: ["**/*.md"]` | Skip if only these changed |
| `workflow_dispatch:` | Adds the manual button |
| `cron: "0 3 * * *"` | minute hour day-of-month month day-of-week |

| | `push` | `pull_request` |
|---|---|---|
| Runs on | The pushed branch | A test merge of the PR into its target |
| Check shown on the PR | Indirectly | ✅ Yes |
| Can block a merge (required check) | — | ✅ Yes |
| Typical use | Deploy after merge | Test before merge |

---

## D — Jobs

```yaml
jobs:
  lint:
    name: Lint with ruff
    runs-on: ubuntu-latest
    timeout-minutes: 10
    defaults:
      run:
        working-directory: day07
    env:
      PYTHONUNBUFFERED: "1"
    steps:
      - uses: actions/checkout@v6
      - run: echo "linting…"
```
| Key | Meaning |
|---|---|
| `lint:` | The job ID (unique; used by `needs:`) |
| `name:` | Readable name in the Actions tab and on the PR check |
| `runs-on:` | The runner |
| `timeout-minutes:` | Safety limit (default 360) |
| `defaults.run.working-directory:` | Folder for every `run:` step — no `cd day07 &&` each time |
| `env:` | Variables for all the job's steps |
| `steps:` | What the job does |

```yaml
jobs:
  lint:       { runs-on: ubuntu-latest, steps: [ … ] }
  test:       { runs-on: ubuntu-latest, steps: [ … ] }
  build-scan:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps: [ … ]
```
```text
   lint ──┐
          ├──► build-scan      (lint and test in parallel; build-scan after both)
   test ──┘
```
| Behaviour | Meaning |
|---|---|
| No `needs:` | Jobs start at the same time on separate runners |
| `needs: [lint, test]` | Waits for both |
| A needed job fails | The dependent job is **skipped** |
| Each job | Becomes its own **check** on the PR: `<workflow> / <job name>` |

| Separate jobs when… | Steps of one job when… |
|---|---|
| Independent, parallel, separate checks (lint vs test) | Later steps need earlier output (`docker build` → Trivy scan of that image) |

---

## E — Steps

| Kind | Key | Does | Example |
|---|---|---|---|
| Command | `run:` | Shell commands on the runner (bash on Ubuntu) | `run: pytest -q` |
| Action | `uses:` | A ready-made reusable step | `uses: actions/checkout@v6` |

```yaml
steps:
  - name: Check out repository code
    uses: actions/checkout@v6
  - name: Set up Python
    uses: actions/setup-python@v6
    with:
      python-version: "3.12"
  - name: Install dependencies
    run: |
      pip install --upgrade pip
      pip install -r requirements-dev.txt
  - name: Run the tests
    run: pytest -q
    env:
      APP_ENV: test
  - name: Only on manual runs
    if: github.event_name == 'workflow_dispatch'
    run: echo "triggered by hand"
```
| Key | Meaning |
|---|---|
| `- ` | Each list item is one step |
| `name:` | Label in the logs |
| `uses: owner/repo@version` | Run an action (pinned) |
| `with:` | Inputs for the action |
| `run:` · `run: \|` | One command · a multi-line block |
| `env:` | Variables for this step |
| `if:` | Run only when the condition is true |
| `working-directory:` | Folder for this step |

| Rule | Meaning |
|---|---|
| Exit code 0 | Step ✅, next step |
| Exit code ≠ 0 | Step ❌ → job ❌ → remaining steps skipped |
| Multi-line `run:` | Runs with `bash -e`: the first failing line stops the step |
| `if: always()` | Run even after a failure (e.g. upload logs) |

### Do we need `actions/checkout`?
**Yes, in almost every job** — the runner starts empty.

| Job | Needs repo files? | Checkout? |
|---|---|---|
| lint, test, build + scan | ✅ | Yes — first step, once per job |
| Deploy an image already in a registry | ❌ | Often no |
| Notify / call an API | ❌ | No |

| Default behaviour | Meaning |
|---|---|
| Clones into `${{ github.workspace }}` | Where `run:` steps start |
| `pull_request` → the PR merged into its target | What would land on merge |
| Shallow (`fetch-depth: 1`) | Latest commit only; `fetch-depth: 0` for full history |
| Uses `GITHUB_TOKEN` | No password for your own private repo |

Forgetting it gives errors like `file or directory not found: tests` — the command ran on an empty machine.

### The Quickstart demo, line by line
```yaml
name: GitHub Actions Demo
run-name: ${{ github.actor }} is testing out GitHub Actions 🚀
on: [push]
jobs:
  Explore-GitHub-Actions:
    runs-on: ubuntu-latest
    steps:
      - run: echo "🎉 The job was automatically triggered by a ${{ github.event_name }} event."
      - run: echo "🐧 This job is now running on a ${{ runner.os }} server hosted by GitHub!"
      - run: echo "🔎 The name of your branch is ${{ github.ref }} and your repository is ${{ github.repository }}."
      - name: Check out repository code
        uses: actions/checkout@v6
      - run: echo "💡 The ${{ github.repository }} repository has been cloned to the runner."
      - run: echo "🖥️ The workflow is now ready to test your code on the runner."
      - name: List files in the repository
        run: |
          ls ${{ github.workspace }}
      - run: echo "🍏 This job's status is ${{ job.status }}."
```
| Line | Meaning |
|---|---|
| `name: GitHub Actions Demo` | Workflow name in the Actions tab |
| `run-name: ${{ github.actor }} …` | Title of each run, from who triggered it |
| `on: [push]` | Trigger: every push |
| `Explore-GitHub-Actions:` | The single job's ID |
| `runs-on: ubuntu-latest` | A fresh GitHub-hosted Ubuntu machine |
| `${{ github.event_name }}` | → `push` |
| `${{ runner.os }}` | → `Linux` |
| `${{ github.ref }}` / `${{ github.repository }}` | The branch ref / `owner/repo` |
| `uses: actions/checkout@v6` | Clone the repo — before this, the runner has none of your files |
| `ls ${{ github.workspace }}` | List the cloned files |
| `${{ job.status }}` | → `success` |

---

## F — Runners

| Term | Definition | Example |
|---|---|---|
| **GitHub-hosted runner** | A machine GitHub provides, patches and maintains. | `runs-on: ubuntu-latest` |
| **Fresh VM per job** | Every job gets a new VM, deleted afterwards — clean and reproducible. | Nothing leaks between runs |
| **OS labels** | `ubuntu-latest`, `ubuntu-24.04`, `windows-latest`, `macos-latest`. Pin a version for stability. | `ubuntu-24.04` |
| **Preinstalled tools** | Git, Docker, Python, Node, `gh`, `curl`, `jq`, … | `docker build` needs no setup |
| **Minutes and OS** | On private repos Linux is cheapest; Windows ≈ 2×, macOS ≈ 10× the minutes. | Use Ubuntu |
| **Ephemeral** | Files, images and installed tools vanish after the job. | Hence caching and checkout per job |
| **Self-hosted runner** | Your own machine running GitHub's agent. | `runs-on: [self-hosted, linux]` |

| | GitHub-hosted | Self-hosted |
|---|---|---|
| Setup | None | Install and register an agent |
| Clean state | ✅ Fresh VM per job | ❌ You clean up |
| Maintenance | GitHub | You |
| Security | Isolated | Never on a public repo — anyone's PR runs on your machine |
| Use | Our sprint | GPUs, private networks, heavy builds |

```yaml
- run: |
    cat /etc/os-release | head -2
    nproc && free -h | head -2
    docker --version && python3 --version
```
| Command | Shows |
|---|---|
| `cat /etc/os-release \| head -2` | The OS (Ubuntu 24.04) |
| `nproc` · `free -h` | CPUs · memory |
| `docker --version` · `python3 --version` | Preinstalled tools |

---

## G — Secrets

| Term | Definition | Example |
|---|---|---|
| **Secret** | An encrypted value stored in GitHub, used by workflows without appearing in code or logs. | `DB_PASSWORD` |
| **Repository secret** | Available to all workflows in one repo. | Settings → Secrets and variables → Actions |
| **Environment secret** | Only for jobs using that environment (can require approval). | `production` |
| **Organization secret** | Shared across an org's repos. | Not used in the sprint |
| **Variable** | Plain, non-secret config; visible in logs. | `${{ vars.APP_ENV }}` |
| **Masking** | Printed secret values show as `***`. | Logs |
| **Write-only** | Values can't be read back after saving — only replaced or deleted. | `gh secret list` shows names only |
| **Fork PRs** | Don't receive secrets. | Strangers can't steal them |
| **`GITHUB_TOKEN`** | A short-lived token GitHub creates per run, revoked at the end. | Used by checkout and `gh` |
| **`permissions:`** | Limits `GITHUB_TOKEN` — least privilege. | `contents: read` |

```yaml
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-24.04
    env:
      APP_ENV: ${{ vars.APP_ENV }}
    steps:
      - uses: actions/checkout@v6
      - name: Integration test
        env:
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
        run: ./run-integration-tests.sh
```
| Line | Meaning |
|---|---|
| `permissions: contents: read` | The token may only read the repo |
| `APP_ENV: ${{ vars.APP_ENV }}` | A non-secret variable |
| `DB_PASSWORD: ${{ secrets.DB_PASSWORD }}` | The secret, handed to the step as an environment variable |

```bash
gh secret set DB_PASSWORD
gh secret list
```
| Command | Meaning |
|---|---|
| `gh secret set DB_PASSWORD` | Prompt for the value; store it encrypted in the repo |
| `gh secret list` | Names and dates only — values can never be read back |

| Rule | Why |
|---|---|
| Never `echo` a secret | Masking only catches exact matches |
| Secrets → env vars, not arguments | Arguments can appear in process lists and logs |
| Least-privilege `permissions:` | A stolen token can do less |
| No cloud access keys as secrets | Day 9 uses OIDC — no long-lived key to leak |
| Leaked → rotate | Deleting doesn't undo a leak |

> The Day 8 lab needs **no secrets** (ruff, pytest, docker build, Trivy) — only `permissions: contents: read`.

---

## H — Caching

| Term | Definition | Example |
|---|---|---|
| **Cache** | Files saved from one run and restored in later runs to skip slow work. | pip downloads |
| **path** | What to save and restore. | `~/.cache/pip` |
| **key** | The cache's name; same key = reuse. Build it from a hash of the dependency file. | `pip-Linux-<hash>` |
| **hit / miss** | Key found → restored · not found → run normally, save at the end. | `Cache restored from key: …` |
| **restore-keys** | Fallback prefix: reuse the closest older cache on a miss. | `pip-Linux-` |
| **`hashFiles()`** | Fingerprint of file contents: change the file → new key. | `hashFiles('day07/requirements*.txt')` |

```yaml
- uses: actions/setup-python@v6
  with:
    python-version: "3.12"
    cache: pip
    cache-dependency-path: day07/requirements-dev.txt
- run: pip install -r day07/requirements-dev.txt
```
| Line | Meaning |
|---|---|
| `cache: pip` | Save/restore pip's download cache automatically |
| `cache-dependency-path:` | Which file the key is hashed from — needed because requirements live in `day07/`, not the root |

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: pip-${{ runner.os }}-${{ hashFiles('day07/requirements*.txt') }}
    restore-keys: |
      pip-${{ runner.os }}-
```
| Line | Meaning |
|---|---|
| `path:` | Folder to save/restore |
| `key:` | OS + hash of the requirements files |
| `restore-keys:` | On a miss, the newest cache starting with `pip-Linux-` |

| Docker layer caching | Meaning |
|---|---|
| The problem | Fresh runners have no Docker layer cache → `docker build` from scratch |
| The fix | Buildx `cache-from: type=gha` / `cache-to: type=gha,mode=max` |
| For us | The Alpine build is quick — optional |

| Limit | Meaning |
|---|---|
| 10 GB per repo | Oldest caches evicted when full |
| 7 days unused | Removed automatically |
| No secrets in caches | Other branches' runs can restore them |
| Branch scope | A PR can read caches from its base branch |

Where to see them: Actions tab → **Caches**, or `gh cache list`.

---

## Check-your-understanding answers

| Section | Q | Answer |
|---|---|---|
| A | CI vs CD? | CI builds and tests every change; CD delivers/deploys what passed. |
| A | Where must workflow files be? | `.github/workflows/`, as `.yml`/`.yaml`. |
| A | Where to see why a run failed? | Actions → workflow → run → job → step log, or **Details** on the PR check. |
| B | Job vs step? | Job = set of steps on one runner; step = one task in it. |
| B | Why checkout in both jobs? | Each job is a separate fresh machine. |
| B | A pytest failure? | Non-zero exit → step fails → job ❌ → later steps skipped. |
| B | Why `@v6`, not `@main`? | `@main` can change or be compromised; pinned = repeatable and safer. |
| C | Why `pull_request` for the lab? | It shows a check on the PR that can be required to block merging. |
| C | What does `paths: ["day07/**"]` do? | Runs only when `day07/` files change — not for unrelated day folders. |
| C | PRs into labs + manual button? | `on: { pull_request: { branches: [labs] }, workflow_dispatch: }` |
| C | `cron: "30 6 * * 1"`? | Mondays 06:30 UTC. |
| D | Order without `needs:`? | All in parallel. |
| D | `test` fails — `build-scan`? | Skipped. |
| D | Why build and scan in one job? | The scan needs the image built on that machine. |
| D | `working-directory: day07` saves? | `cd day07 &&` before every `run:`. |
| E | `run:` vs `uses:`? | Your commands vs a ready-made action. |
| E | `ls ${{ github.workspace }}` without checkout? | None of your files. |
| E | Line 2 of 3 fails? | Line 3 doesn't run (`bash -e`), the job fails, next steps are skipped. |
| E | `with:` is for? | Inputs to an action. |
| F | Fresh VM per job means? | No files or images carry over between jobs. |
| F | `ubuntu-24.04` vs `ubuntu-latest`? | `latest` moves; a pinned version is repeatable. |
| F | Self-hosted on a public repo? | Anyone's PR would run code on your machine. |
| F | Install Docker in the lab? | No — it's preinstalled. |
| G | Where's a CI password, how is it used? | Repo secret → `env:` with `${{ secrets.NAME }}`. |
| G | A printed secret looks like? | `***` |
| G | `GITHUB_TOKEN` + `permissions`? | A per-run token; `contents: read` = least privilege. |
| G | Secret vs variable? | Sensitive vs plain config. |
| H | Why re-download without a cache? | Fresh VM every job. |
| H | Why a `hashFiles` key? | It changes only when dependencies change. |
| H | `restore-keys` on a miss? | The closest older cache — only changed packages download. |
| H | Why `cache-dependency-path`? | Requirements are in `day07/`, not the repo root. |

---

## Key takeaways

| Topic | Remember |
|---|---|
| Where | `.github/workflows/*.yml` |
| Flow | Event → workflow → jobs (parallel or `needs`) → steps (in order) on runners |
| Triggers | `pull_request` for checks that can block a merge; filter with `branches` / `paths` |
| Jobs | Separate machines; each job is a PR check; `needs:` orders them |
| Steps | `run:` commands or `uses:` actions; non-zero exit fails the job |
| Checkout | First step of every job that needs the code |
| Runners | GitHub-hosted, fresh per job, Docker preinstalled; pin `ubuntu-24.04` |
| Secrets | Encrypted, masked, write-only; via `env:`; `permissions: contents: read`; OIDC instead of keys |
| Caching | Key from `hashFiles(requirements)`; `setup-python` `cache: pip` + `cache-dependency-path` |
| Pin versions | Actions (`@v6`) and runners (`ubuntu-24.04`), like Docker tags |
