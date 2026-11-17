[⬅ Back to labs](../SPRINT.md)

# Day 8 Lab — CI on Every PR, and a Failing Check Blocks the Merge

**The task (sprint plan):** On every PR, run **lint (ruff)**, **unit tests (pytest)**, **`docker build`** and an **image scan with Trivy**. **A failing check blocks the merge.**

**Date:** 2026-11-17 · **Where:** WSL Ubuntu 24.04 + Docker Desktop 29.6.1 + GitHub Actions · **Cost:** $0 (a few of the 2,000 free Actions minutes)
**Result:** workflow `.github/workflows/day08-ci.yml` and folder `day08/` on `labs` via **PR #14** (`b6b1c9f`); the 3 checks are **required**; **PR #15** (deliberately broken) is **BLOCKED**.

| Requirement | Result |
|---|---|
| Lint (ruff) on every PR | ✅ job `lint (ruff)` — 10 s |
| Unit tests (pytest) on every PR | ✅ job `test (pytest)` — 21 s, pip cache |
| `docker build` + Trivy scan | ✅ job `build + scan (docker, trivy)` — 34 s |
| A failing check blocks the merge | ✅ required checks on `labs`; PR #15 shows `BLOCKED` |

### Versions (latest releases, pinned)
| Tool | Version | Note |
|---|---|---|
| `actions/checkout` | **v7** | The docs page still shows v6 |
| `actions/setup-python` | **v7** | |
| ruff | **0.17.5** | Python linter |
| Trivy | **0.76.2** | Run as the `aquasec/trivy` image |
| actionlint | **1.7.12** | Lints the workflow YAML |
| Runner | **`ubuntu-24.04`** | Pinned, not `-latest` |

| Part | What | Time |
|---|---|---|
| 1 | `day08/` from Day 7, the fix Trivy needs, the 4 checks locally | 15 min |
| 2 | The workflow file + actionlint | 10 min |
| 3 | Push, open PR #14, watch CI | 10 min |
| 4 | Make the 3 checks required, merge | 10 min |
| 5 | Prove it: PR #15 is blocked | 15 min |

```text
PR into labs ──► Day 8 CI
                 ├── lint (ruff) ─────┐
                 ├── test (pytest) ───┼──► build + scan (docker, trivy)   (needs both)
                 │                    │
                 └── all 3 required ──┴──► ✅ merge allowed · ❌ merge BLOCKED
```

---

## Part 1 — `day08/` and local checks

### 1.1 Setup
```bash
docker version --format '{{.Server.Version}}'
cd ~/Devops-Sprint-Wisam
git switch labs && git pull
git switch -c lab/day08-ci
cp -r day07 day08
rm -f day08/.env
ls -A day08
```
| Command | Meaning |
|---|---|
| `docker version --format '{{.Server.Version}}'` | `29.6.1` = Docker ready (otherwise restart Docker Desktop) |
| `git switch labs && git pull` | Start from the latest labs branch |
| `git switch -c lab/day08-ci` | A topic branch for this lab |
| `cp -r day07 day08` | Day 8 starts from a copy of Day 7 — each day keeps its own folder |
| `rm -f day08/.env` | Remove the copied local `.env` (it has the password; CI doesn't need it) |
| `ls -A day08` | `app/`, `tests/`, `Dockerfile`, `compose.yaml`, `.env.example`, … — no `.env` |

### 1.2 Scan the Day 7 image — it fails
```bash
cd day08
docker build -t day08:before .
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:0.76.2 image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 day08:before
echo "trivy exit=$?"
```
| Part | Meaning |
|---|---|
| `docker build -t day08:before .` | Build the unchanged Day 7 Dockerfile |
| `aquasec/trivy:0.76.2` | The official Trivy image, pinned — nothing to install |
| `-v /var/run/docker.sock:/var/run/docker.sock` | Lets Trivy (in its container) ask your Docker for the image |
| `image … day08:before` | Scan the image's OS and Python packages |
| `--severity HIGH,CRITICAL` | Only serious issues |
| `--ignore-unfixed` | Skip vulnerabilities with no fix yet — nothing you could do |
| `--exit-code 1` | Exit 1 when something is found → in CI the job fails |
| **Result** | **16 HIGH**, all fixable, in Alpine OS packages (mostly `krb5`); Python packages: none at HIGH → `trivy exit=1` |

### 1.3 The fix — patch Alpine's packages during the build
```bash
sed -i 's/^RUN adduser -D -u 10001 app$/RUN apk upgrade --no-cache \&\& adduser -D -u 10001 app/' Dockerfile
grep -n 'apk upgrade' Dockerfile
```
| Part | Meaning |
|---|---|
| `apk upgrade` | Alpine's package manager: update all installed OS packages to patched versions |
| `--no-cache` | No package index left in the layer |
| `&& adduser …` | Same `RUN` → one layer |
| Runtime stage | The image that ships is where patches matter |
| `grep -n …` | `11:RUN apk upgrade --no-cache && adduser -D -u 10001 app` |

### 1.4 The four checks, locally
```bash
docker run --rm -v "$PWD":/src -w /src python:3.12-slim \
  sh -c "pip install -q --root-user-action=ignore ruff==0.17.5 && ruff check ."
docker run --rm -v "$PWD":/src -w /src python:3.12-slim \
  sh -c "pip install -q --root-user-action=ignore -r requirements-dev.txt && pytest -q -p no:cacheprovider"
docker build -t day08:after .
docker images day08
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:0.76.2 image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 day08:after
echo "trivy exit=$?"
docker rmi day08:before day08:after
```
| Check | Command meaning | Result |
|---|---|---|
| ruff | Install the pinned linter in a throwaway Python container; `ruff check .` lints the code | `All checks passed!` |
| pytest | Install app + test tools; run the tests (`-p no:cacheprovider` = no root-owned cache files) | `2 passed` |
| docker build | Build with the fix | `day08:after` **120 MB** (before: 117 MB) — still under 150, still `uid=10001` |
| Trivy | Same scan | No findings → **`trivy exit=0`** |
| `docker rmi …` | Remove the two test images | — |

> **Lint vs format:** `ruff check` (lint) passes. `ruff format --check` would reformat one file (a missing blank line) — style only; the plan asks for lint.

---

## Part 2 — The workflow file

Workflows live in **`.github/workflows/` at the repo root**, not inside `day08/`.
```bash
cd ~/Devops-Sprint-Wisam
mkdir -p .github/workflows
cat > .github/workflows/day08-ci.yml <<'EOF'
name: Day 8 CI

on:
  pull_request:
    branches: [labs]
  workflow_dispatch:

permissions:
  contents: read

defaults:
  run:
    working-directory: day08

jobs:
  lint:
    name: lint (ruff)
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: "3.12"
      - name: Install ruff
        run: pip install ruff==0.17.5
      - name: Lint
        run: ruff check .

  test:
    name: test (pytest)
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: day08/requirements-dev.txt
      - name: Install dependencies
        run: pip install -r requirements-dev.txt
      - name: Run the tests
        run: pytest -v

  build-scan:
    name: build + scan (docker, trivy)
    needs: [lint, test]
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
      - name: Build the image
        run: docker build -t capstone:${{ github.sha }} .
      - name: Scan with Trivy (fail on fixable HIGH/CRITICAL)
        run: |
          docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:0.76.2 image \
            --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 \
            capstone:${{ github.sha }}
EOF
```
| Line | Meaning (notes section) |
|---|---|
| `name: Day 8 CI` | Workflow name; checks appear as `Day 8 CI / <job name>` (A) |
| `on: pull_request: branches: [labs]` | Trigger: every PR into `labs` (C). **No `paths:` filter on purpose** — a required check must run on every PR, or unrelated PRs would wait forever |
| `workflow_dispatch:` | Manual **Run workflow** button (C) |
| `permissions: contents: read` | `GITHUB_TOKEN` can only read (G) |
| `defaults: run: working-directory: day08` | Every `run:` step starts in `day08/` (D) |
| `lint:` · `name: lint (ruff)` | Job 1; the `name` is the check name on the PR (D) |
| `runs-on: ubuntu-24.04` | Pinned GitHub-hosted runner (F) |
| `timeout-minutes: 10` | Kill a stuck job (D) |
| `uses: actions/checkout@v7` | Clone the repo — first step of every job (E) |
| `uses: actions/setup-python@v7` + `python-version: "3.12"` | Install Python 3.12 (E) |
| `pip install ruff==0.17.5` → `ruff check .` | Install the pinned linter; lint the code |
| `test:` | Job 2 — parallel with `lint` (D) |
| `cache: pip` + `cache-dependency-path: day08/requirements-dev.txt` | Cache pip downloads, keyed on that file (H) |
| `pip install -r requirements-dev.txt` → `pytest -v` | App + test tools; run tests |
| `build-scan:` · `needs: [lint, test]` | Job 3 — only after both pass (D) |
| `docker build -t capstone:${{ github.sha }} .` | Build, tagged with the commit SHA; Docker is preinstalled (F) |
| `docker run … aquasec/trivy:0.76.2 image … --exit-code 1` | Scan that image (same job, same machine); exit 1 → job ❌ |

### Check the YAML before pushing
```bash
docker run --rm -i rhysd/actionlint:1.7.12 -color=false - < .github/workflows/day08-ci.yml && echo "actionlint OK"
```
| Part | Meaning |
|---|---|
| `rhysd/actionlint:1.7.12` | A linter for GitHub Actions: wrong keys, typos, bad `needs:` |
| `-i … - < file` | Read the workflow from stdin |
| Result | `actionlint OK` (a deliberately wrong `needs: [lint, tests]` is reported: *job "tests" does not exist*) |

---

## Part 3 — Push, open the PR, watch CI

### 3.1 Stage and check
```bash
cd ~/Devops-Sprint-Wisam
git status -s
git add .github/workflows/day08-ci.yml day08/
git diff --cached --name-only
git diff --cached --name-only | grep -x 'day08/.env' && echo "STOP: .env is staged" || echo "no .env staged"
```
| Command | Meaning |
|---|---|
| `git status -s` | `?? .github/`, `?? day08/` (+ old practice files) |
| `git add .github/workflows/day08-ci.yml day08/` | Stage only the workflow and the Day 8 folder |
| `git diff --cached --name-only` | What will be committed |
| `grep -x 'day08/.env' && … \|\| …` | Must print `no .env staged` |

### 3.2 Commit, push, PR
```bash
git commit -m "ci: add Day 8 workflow (ruff, pytest, docker build, Trivy)"
git push -u origin lab/day08-ci
gh pr create --base labs --title "ci: Day 8 - lint, tests, docker build and Trivy on every PR" \
  --body "Adds .github/workflows/day08-ci.yml and day08/ (Day 7 app + apk upgrade)."
```
| Command | Meaning |
|---|---|
| `ci:` | Conventional Commits type for CI changes |
| `git push -u origin lab/day08-ci` | Upload the branch |
| `gh pr create --base labs …` | Opening the PR is the **event** that starts the workflow → **PR #14** |

### 3.3 Watch and inspect
```bash
gh pr checks --watch
gh run list --limit 3
gh run view
gh pr view --web
```
| Command | Meaning |
|---|---|
| `gh pr checks --watch` | Follow the checks until they finish |
| `gh run list --limit 3` | Recent runs: workflow, status, event, branch |
| `gh run view` | One run's jobs and durations |
| `gh pr view --web` | The PR in the browser — checks box → **Details** → step logs |

**Result (PR #14):**
| Check | Result | Time |
|---|---|---|
| `lint (ruff)` | ✅ pass | 10 s |
| `test (pytest)` | ✅ pass | 21 s |
| `build + scan (docker, trivy)` | ✅ pass | 34 s — started after the other two |

On the first run, `setup-python` reports a **cache miss** and saves the pip cache at the end; later runs restore it.

---

## Part 4 — Required checks, then merge

### 4.1 Add required status checks to `labs`
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
gh api -X PUT "repos/$REPO/branches/labs/protection" --input - <<'EOF'
{
  "required_status_checks": {
    "strict": false,
    "checks": [
      {"context": "lint (ruff)"},
      {"context": "test (pytest)"},
      {"context": "build + scan (docker, trivy)"}
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {"required_approving_review_count": 0},
  "restrictions": null
}
EOF
```
| Part | Meaning |
|---|---|
| `REPO=$(gh repo view …)` | `owner/repo` in a variable |
| `-X PUT …/branches/labs/protection` | Replace the whole rule set of `labs` — that's why the old rules are repeated |
| `required_status_checks` | **New:** checks that must pass before merging |
| `checks: [{"context": "…"}]` | The exact check names = the jobs' `name:` values. A typo = a check that never arrives → PRs wait forever |
| `"strict": false` | The PR needn't be up to date with `labs` first |
| `"enforce_admins": true` | Kept — rules apply to the owner too |
| `required_pull_request_reviews … 0` | Kept — a PR is required |
| `"restrictions": null` | Kept — no per-user push list |

> A check can only be required after it has **run at least once** — PR #14 provided that.

### 4.2 Verify
```bash
gh api "repos/$REPO/branches/labs/protection" \
  -q '{required_checks: [.required_status_checks.checks[].context], admins: .enforce_admins.enabled, pr_required: (.required_pull_request_reviews != null)}'
```
**Result:** `{"admins":true,"pr_required":true,"required_checks":["lint (ruff)","test (pytest)","build + scan (docker, trivy)"]}` — also visible in **Settings → Branches → labs**.

### 4.3 Merge PR #14
```bash
gh pr checks 14
gh pr review 14 --comment --body "Self-review: workflow + day08/, all 3 checks green, no .env."
gh pr merge 14 --squash --delete-branch
git switch labs && git pull
git log --oneline -2
ls .github/workflows day08
```
| Command | Meaning |
|---|---|
| `gh pr checks 14` | All 3 `pass` → merging allowed |
| `gh pr review 14 --comment …` | Record the self-review |
| `gh pr merge 14 --squash --delete-branch` | Merge into `labs`, delete the branch |
| `git log --oneline -2` | `b6b1c9f ci: add Day 8 workflow (ruff, pytest, docker build, Trivy) (#14)` |
| `ls .github/workflows day08` | The workflow and the Day 8 app are on `labs` |

---

## Part 5 — Prove it: a broken PR is blocked

### 5.1 Two deliberate mistakes
```bash
git switch labs && git pull
git switch -c lab/day08-break
sed -i '1a import os' day08/app/main.py
sed -i 's/"status": "ok"}/"status": "broken"}/' day08/app/main.py
git diff
```
| Command | Meaning |
|---|---|
| `git switch -c lab/day08-break` | A throwaway branch |
| `sed -i '1a import os' …` | Append an **unused import** after line 1 → ruff error `F401` |
| `sed -i 's/"ok"}/"broken"}/' …` | `/health` returns `"broken"` → the health test fails |
| `git diff` | Shows `+import os` and `ok` → `broken` |

### 5.2 Confirm locally (optional)
```bash
cd day08
docker run --rm -v "$PWD":/src -w /src python:3.12-slim sh -c "pip install -q --root-user-action=ignore ruff==0.17.5 && ruff check ."
cd ..
```
**Result:** `F401 [*] 'os' imported but unused` · `Found 1 error.`

### 5.3 Push and open the PR
```bash
git commit -am "test: deliberately break lint and a test (do not merge)"
git push -u origin lab/day08-break
gh pr create --base labs --title "DO NOT MERGE: prove failing checks block the merge" \
  --body "Deliberate F401 and a broken /health. Expected: lint and test fail, build+scan skipped, merge blocked."
gh pr checks --watch
```
| Command | Meaning |
|---|---|
| `git commit -am` | Stage the changed tracked file and commit |
| `gh pr create …` | Opens **PR #15** → triggers the workflow |
| `gh pr checks --watch` | Follow the checks |

**Result (PR #15):**
| Check | Result | Why |
|---|---|---|
| `lint (ruff)` | ❌ fail | `F401` unused import → exit 1 |
| `test (pytest)` | ❌ fail | `assert 'broken' == 'ok'` → exit 1 |
| `build + scan (docker, trivy)` | ⏭️ skipping | `needs: [lint, test]` failed |
| **Merge state** | **`BLOCKED`** | Required checks failing |

### 5.4 Try to merge — refused
```bash
gh pr merge --squash
```
| Result | Rule |
|---|---|
| Refused — required status checks failing; in the browser the merge button is disabled ("Merging is blocked") | `required_status_checks` |
| The owner can't override it either | `enforce_admins: true` |

### 5.5 Read the failure
```bash
gh run view --log-failed | grep -E 'F401|assert|Error|failed' | head -10
```
| Part | Meaning |
|---|---|
| `gh run view --log-failed` | Only the logs of failed steps |
| `grep -E …` | Keep the ruff code and pytest's assertion |

### 5.6 PR #15 is kept open as a live example
```bash
git switch labs && git pull
git branch --show-current
```
| Command | Meaning |
|---|---|
| `git switch labs && git pull` | Leave the broken branch so new work starts from clean code |
| `git branch --show-current` | `labs` |

| Later | Commands |
|---|---|
| **Fix it and watch it turn green** | `git switch lab/day08-break` → `sed -i '/^import os$/d' day08/app/main.py` → `sed -i 's/"status": "broken"}/"status": "ok"}/' day08/app/main.py` → `git commit -am "fix: restore lint and health"` → `git push` → `gh pr checks 15 --watch` |
| **Throw it away** | `gh pr close 15 --delete-branch` |

Keeping it open is harmless: it can't be merged, and it uses no Actions minutes unless you push to it.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| A required check stays "Expected — Waiting for status" | Check name in protection ≠ job `name:`, or the workflow didn't run (e.g. a `paths:` filter) | Match the names exactly; no `paths:` on required workflows |
| `file or directory not found: tests` | Missing `actions/checkout` in that job | Add checkout as the first step |
| Trivy fails on a fresh base image | OS packages in the base image are behind | `apk upgrade --no-cache` in the runtime stage (or a newer base tag) |
| `ruff check` fails with `F401` | Unused import | Remove it, or `ruff check --fix` |
| `docker` not found / `Input/output error` in WSL | Docker Desktop engine stopped | Restart Docker Desktop |
| Workflow doesn't start | File not in `.github/workflows/`, wrong extension, or YAML error | Check path; run actionlint |

## Commands to remember
| Goal | Command |
|---|---|
| Watch a PR's checks | `gh pr checks --watch` |
| Recent runs | `gh run list --limit 5` |
| Failed steps only | `gh run view --log-failed` |
| Run manually | `gh workflow run day08-ci.yml --ref labs` |
| Lint the workflow | `docker run --rm -i rhysd/actionlint:1.7.12 - < .github/workflows/day08-ci.yml` |
| Scan an image | `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.76.2 image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 <image>` |
| Required checks | `gh api repos/<owner>/<repo>/branches/labs/protection -q '[.required_status_checks.checks[].context]'` |
