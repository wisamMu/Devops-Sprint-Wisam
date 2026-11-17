[⬅ Back to labs](../SPRINT.md)

# Day 9 Lab — Push to ECR from GitHub Actions with OIDC (No Access Keys)

**The task (sprint plan):** Create a **GitHub OIDC provider** and a **role trusted only by your repo and branch**. **On merge, push the image to ECR tagged with the git SHA.** **No access keys in GitHub secrets.**

**Date:** 2026-11-17 · **Where:** WSL Ubuntu 24.04 + AWS CLI (`aws login`, profile `sprint2`) + GitHub Actions · **Region:** `us-east-1`
**Cost:** IAM, OIDC and STS are free; ECR storage ≈ **$0.003/month** (one 27 MB image, $0.10 per GB-month); pushes (data in) are free.
**Result:** workflow `.github/workflows/day09-push.yml` on `labs` via **PR #18** (`ec0a5a6f`); run `44100642563` (32 s) assumed role `gha-ecr-push` and pushed **`capstone:ec0a5a6f7eafc1cc28e72ef6fa93a4f4db41b523`**; `gh secret list` → **no secrets found**.

> The 12-digit AWS account ID is written as `<id>` everywhere in this file.

| Requirement | Result |
|---|---|
| GitHub OIDC provider in AWS | ✅ `arn:aws:iam::<id>:oidc-provider/token.actions.githubusercontent.com` |
| Role trusted only by this repo + branch | ✅ `gha-ecr-push`: `aud` = `sts.amazonaws.com`, `sub` = this repo (by ID) on `labs` only |
| On merge, push to ECR tagged with the git SHA | ✅ merge of PR #18 → `capstone:ec0a5a6f…` (tag = merge commit) |
| No access keys in GitHub secrets | ✅ `no secrets found`; the role ARN is a plain **variable** |

### Versions (pinned)
| Tool | Version | Note |
|---|---|---|
| `aws-actions/configure-aws-credentials` | **v6.3.0** | OIDC token → STS → temporary keys |
| `aws-actions/amazon-ecr-login` | **v2.1.7** | `docker login` to ECR |
| `actions/checkout` | **v7** | |
| Runner | **`ubuntu-24.04`** | Docker + AWS CLI preinstalled |
| actionlint | **1.7.12** | Lints the workflow YAML |

| Part | What | Time |
|---|---|---|
| 0 | Warm-up without AWS: print the OIDC token's claims | 15 min |
| 1 | Use the new account (profile, account ID) | 5 min |
| 2 | The GitHub OIDC provider | 5 min |
| 3 | The ECR repo `capstone` + lifecycle rule | 10 min |
| 4 | The role `gha-ecr-push`: trust + permissions | 15 min |
| 5 | Repo variable, workflow, PR #18, merge | 15 min |
| 6 | Prove it, and review it in the console | 10 min |

```text
merge PR into labs ──► "Day 9 push to ECR" (GitHub runner)
   │  1. ask GitHub for an OIDC token (id-token: write)      sub = repo:…@1443987341:ref:refs/heads/labs
   │  2. STS AssumeRoleWithWebIdentity(token, role ARN)
   │        AWS checks: signature (OIDC provider) + aud/sub (role trust policy)
   │  3. STS → temporary keys (1 h) for role gha-ecr-push
   │  4. ECR login → docker build day08 → docker push capstone:<git-sha>
   ▼
ECR us-east-1 / capstone:ec0a5a6f…      (no AWS keys stored anywhere)
```

---

## Part 0 — Warm-up without AWS: see the token

A throwaway workflow on a side branch (`lab/day09-oidc-claims`, **not merged**) asks GitHub for an OIDC token and prints only its **claims**, never the token.

```yaml
name: Day 9 OIDC claims

on:
  push:
    branches: [lab/day09-oidc-claims]

permissions:
  contents: read
  id-token: write

jobs:
  show-claims:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Request an OIDC token and print its claims (never the token)
        run: |
          RESPONSE=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com")
          JWT=$(echo "$RESPONSE" | jq -r '.value')
          echo "::add-mask::$JWT"
          PAYLOAD=$(echo "$JWT" | cut -d. -f2 | tr '_-' '/+')
          while [ $(( ${#PAYLOAD} % 4 )) -ne 0 ]; do PAYLOAD="${PAYLOAD}="; done
          echo "$PAYLOAD" | base64 -d | jq '{iss, aud, sub, repository, repository_id, repository_owner, repository_owner_id, ref, event_name, sha, iat, exp}'
```
| Line | Meaning |
|---|---|
| `permissions: id-token: write` | Allows the job to request an OIDC token. Without it, the two variables below don't exist. |
| `$ACTIONS_ID_TOKEN_REQUEST_URL` / `_TOKEN` | Built-in variables GitHub gives the job: where to ask and the bearer token to ask with |
| `&audience=sts.amazonaws.com` | Sets the token's `aud` claim — who the token is meant for |
| `jq -r '.value'` | The response is `{"value":"<JWT>"}`; take the JWT |
| `::add-mask::$JWT` | Hide the token as `***` if it ever appears in the log |
| `cut -d. -f2` | A JWT is `header.payload.signature`; take the payload |
| `tr '_-' '/+'` + the `while` loop | Base64**url** → normal Base64, and add `=` padding |
| `base64 -d \| jq '{…}'` | Decode and print chosen claims |

**Result (run `44067962656`):**
| Claim | Value |
|---|---|
| `iss` | `https://token.actions.githubusercontent.com` |
| `aud` | `sts.amazonaws.com` |
| `sub` | `repo:wisamMu@66379795/Devops-Sprint-Wisam@1443987341:ref:refs/heads/lab/day09-oidc-claims` |
| `exp − iat` | **300 s** — the token lives 5 minutes |

The `sub` uses the **immutable** form (`owner@ownerId/repo@repoId`) — this repo was created after GitHub switched to it. The trust policy in Part 4 must match it exactly.

---

## Part 1 — Use the new account

```bash
aws sts get-caller-identity --profile sprint2 --query Arn --output text
export AWS_PROFILE=sprint2
aws configure list
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "account set: ${#ACCOUNT_ID} digits"
```
| Command | Meaning |
|---|---|
| `get-caller-identity --profile sprint2` | "Who am I?" → `arn:aws:iam::<id>:user/DevOps` |
| `export AWS_PROFILE=sprint2` | Every `aws` command in this terminal uses the `sprint2` profile (no `--profile` needed) |
| `aws configure list` | `profile sprint2 (env)`, keys of type **`login`** (temporary, from `aws login`), region `us-east-1` |
| `ACCOUNT_ID=$(… --query Account …)` | Save the 12-digit ID for building ARNs |
| `${#ACCOUNT_ID}` | Its **length** (`12`) — checks it's set without printing it |

**Profile** = a named set of CLI settings (account, login, region) in `~/.aws/config`. This laptop has two: `default` (old account) and `sprint2` (new).

---

## Part 2 — The GitHub OIDC provider (free)

```bash
aws iam list-open-id-connect-providers
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --tags Key=Project,Value=devops-sprint
aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text
```
| Part | Meaning |
|---|---|
| `list-open-id-connect-providers` | Before: `[]` — none yet |
| `create-open-id-connect-provider` | Register an outside identity provider in IAM |
| `--url https://token.actions.githubusercontent.com` | The **issuer** = the token's `iss`. AWS fetches GitHub's public keys from here to check signatures. |
| `--client-id-list sts.amazonaws.com` | The allowed **audience** = the token's `aud` |
| *(no `--thumbprint-list`)* | Not needed for GitHub anymore — AWS validates GitHub's certificate itself |
| `--tags …` | Find and clean up sprint resources |
| **Result** | `arn:aws:iam::<id>:oidc-provider/token.actions.githubusercontent.com` |

> The provider trusts **GitHub Actions in general**, not this repo — every workflow in the world gets tokens from the same issuer. On its own it lets **nobody** in. The **role's trust policy** (Part 4) picks the repo and branch. One provider per account; more repos = more roles.

**ARN** (Amazon Resource Name) = the unique address of anything in AWS: `arn:partition:service:region:account-id:resource`. IAM is global, so its ARNs have an empty region (`arn:aws:iam::<id>:…`).

---

## Part 3 — The ECR repo `capstone`

### 3.1 Create it
```bash
aws ecr create-repository \
  --repository-name capstone \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --tags Key=Project,Value=devops-sprint \
  --query 'repository.[repositoryName,repositoryUri,imageTagMutability]' --output table
aws ecr list-images --repository-name capstone
```
| Part | Meaning |
|---|---|
| `--repository-name capstone` | Images will be `<registry>/capstone:<git-sha>` |
| `--image-tag-mutability IMMUTABLE` | A tag can never be overwritten — one SHA = one exact image |
| `--image-scanning-configuration scanOnPush=true` | Repo-level basic scan on push (see the note in Part 6) |
| `--encryption-configuration encryptionType=AES256` | AWS-owned key, free. **Not** `KMS` (a paid customer key). |
| `list-images` | `"imageIds": []` — the repo is an **empty shelf**: no image, and ECR never runs containers |

| Address | Used by | Value |
|---|---|---|
| **URI** | Docker (`docker push/pull`) | `<id>.dkr.ecr.us-east-1.amazonaws.com/capstone` |
| **ARN** | IAM policies | `arn:aws:ecr:us-east-1:<id>:repository/capstone` |

### 3.2 Lifecycle rule — keep only the newest image
```bash
aws ecr put-lifecycle-policy \
  --repository-name capstone \
  --lifecycle-policy-text '{"rules":[{"rulePriority":1,"description":"keep only the newest image","selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":1},"action":{"type":"expire"}}]}' \
  --query 'repositoryName' --output text
aws ecr describe-repositories --query 'repositories[].[repositoryName,imageTagMutability,encryptionConfiguration.encryptionType]' --output table
aws ecr get-lifecycle-policy --repository-name capstone --query 'lifecyclePolicyText' --output text
```
| Part | Meaning |
|---|---|
| `"tagStatus":"any"` | Applies to all images, tagged or not |
| `"countType":"imageCountMoreThan","countNumber":1` | Triggers when there's more than 1 image |
| `"action":{"type":"expire"}` | Delete the older ones (ECR runs rules within ~24 h) |
| `describe-repositories` | `capstone | IMMUTABLE | AES256` |

---

## Part 4 — The role `gha-ecr-push`

| Policy | Answers | Analogy |
|---|---|---|
| **Trust policy** | **Who** may become the role? | The guest list |
| **Permissions policy** | **What** may the role do? | The key they receive |

### 4.1 Trust policy — this repo, `labs` only
The exact `sub` comes from GitHub (or Part 0's output):
```bash
gh api repos/wisamMu/Devops-Sprint-Wisam --jq '"repo:\(.owner.login)@\(.owner.id)/\(.name)@\(.id):ref:refs/heads/labs"'
```
→ `repo:wisamMu@66379795/Devops-Sprint-Wisam@1443987341:ref:refs/heads/labs`

```bash
cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsLabsBranchOnly",
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:wisamMu@66379795/Devops-Sprint-Wisam@1443987341:ref:refs/heads/labs"
        }
      }
    }
  ]
}
EOF
python3 -m json.tool /tmp/trust.json > /dev/null && echo "valid JSON"
grep -c "$ACCOUNT_ID" /tmp/trust.json
```
| Part | Meaning |
|---|---|
| `<<EOF` (no quotes) | Bash fills in `${ACCOUNT_ID}` |
| `"Principal": { "Federated": "…oidc-provider/…" }` | Who asks: a holder of a token from the Part 2 provider |
| `"Action": "sts:AssumeRoleWithWebIdentity"` | Swap a web (OIDC) token for this role's temporary keys |
| `"StringEquals"` | The claims must match **exactly** — no wildcards |
| `token.actions.githubusercontent.com:aud` | Condition key = provider URL + `:` + claim. Must be `sts.amazonaws.com`. |
| `token.actions.githubusercontent.com:sub` | Only repo ID `1443987341` of owner ID `66379795`, only branch `labs` |
| `json.tool` / `grep -c` | `valid JSON` and `1` (the ID was filled in) |

### 4.2 Create the role
```bash
aws iam create-role \
  --role-name gha-ecr-push \
  --assume-role-policy-document file:///tmp/trust.json \
  --description "GitHub Actions (Devops-Sprint-Wisam, labs branch) pushes to ECR capstone" \
  --max-session-duration 3600 \
  --tags Key=Project,Value=devops-sprint \
  --query 'Role.Arn' --output text
```
| Part | Meaning |
|---|---|
| `--assume-role-policy-document file:///tmp/trust.json` | Attach the trust policy (`file://` + `/tmp/…`) |
| `--max-session-duration 3600` | Temporary keys live at most 1 hour |
| **Result** | `arn:aws:iam::<id>:role/gha-ecr-push` — can be assumed, but can't do anything yet |

### 4.3 Permissions policy — push to `capstone` only
```bash
cat > /tmp/perms.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcrLogin",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "PushToCapstoneOnly",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "arn:aws:ecr:us-east-1:${ACCOUNT_ID}:repository/capstone"
    }
  ]
}
EOF
python3 -m json.tool /tmp/perms.json > /dev/null && echo "valid JSON"
aws iam put-role-policy \
  --role-name gha-ecr-push \
  --policy-name ecr-push-capstone \
  --policy-document file:///tmp/perms.json && echo "policy attached"
```
| Action | Why `docker push` needs it |
|---|---|
| `ecr:GetAuthorizationToken` on `*` | The Docker login password. It's registry-wide, so it **can't** be limited to one repo. |
| `BatchCheckLayerAvailability` | "Which layers do you already have?" — skip those |
| `InitiateLayerUpload` → `UploadLayerPart` → `CompleteLayerUpload` | Upload each new layer in chunks |
| `PutImage` | Write the manifest + tag → `capstone:<sha>` exists |
| `Resource: …:repository/capstone` | **Only this repo** — least privilege by ARN |
| `put-role-policy` | An **inline** policy: lives inside this role only |

Not allowed on purpose: pull, delete, other repos, creating repos, anything outside ECR.

### 4.4 Verify
```bash
aws iam get-role --role-name gha-ecr-push --query 'Role.AssumeRolePolicyDocument.Statement[0].Condition.StringEquals' --output json
aws iam list-role-policies --role-name gha-ecr-push --output text
aws iam get-role-policy --role-name gha-ecr-push --policy-name ecr-push-capstone --query 'PolicyDocument.Statement[].Action' --output json
rm /tmp/trust.json /tmp/perms.json
```
| Command | Result |
|---|---|
| `get-role … StringEquals` | The same `aud` + `sub` |
| `list-role-policies` | `POLICYNAMES ecr-push-capstone` |
| `get-role-policy … Action` | `GetAuthorizationToken` + the 5 push actions |
| `rm …` | The temp files had the account ID; the live policies stay on the role |

---

## Part 5 — GitHub: variable, workflow, PR, merge

### 5.1 The role ARN as a repo **variable** (not a secret)
```bash
cd ~/Devops-Sprint-Wisam
ROLE_ARN=$(aws iam get-role --role-name gha-ecr-push --query 'Role.Arn' --output text)
gh variable set AWS_ROLE_ARN --body "$ROLE_ARN"
gh variable list
gh secret list
```
| Part | Meaning |
|---|---|
| `gh variable set AWS_ROLE_ARN` | Settings → Secrets and variables → Actions → **Variables** |
| `gh secret list` | `no secrets found` — nothing AWS-related is secret |

| | Variable (`vars.X`) | Secret (`secrets.X`) |
|---|---|---|
| Readable after saving | Yes | No (write-only, masked) |
| For | Non-secret config: region, ARNs | Passwords, tokens, keys |
| Here | The role ARN — an address, useless without a valid token for this repo + branch | Nothing: OIDC needs no stored secret |

### 5.2 The workflow
```bash
git switch labs && git pull
git switch -c lab/day09-ecr-push
cat > .github/workflows/day09-push.yml <<'EOF'
name: Day 9 push to ECR

on:
  push:
    branches: [labs]
    paths:
      - 'day08/**'
      - '.github/workflows/day09-push.yml'
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  push:
    name: push image to ECR (OIDC)
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7

      - name: Get AWS credentials with OIDC (no keys)
        uses: aws-actions/configure-aws-credentials@v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Who am I in AWS?
        run: aws sts get-caller-identity --query Arn --output text

      - name: Log in to ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2.1.7

      - name: Build and push, tagged with the git SHA
        env:
          IMAGE: ${{ steps.ecr.outputs.registry }}/capstone:${{ github.sha }}
        run: |
          docker build -t "$IMAGE" day08
          docker push "$IMAGE"
          echo "pushed $IMAGE"
EOF
docker run --rm -i rhysd/actionlint:1.7.12 -color=false - < .github/workflows/day09-push.yml && echo "actionlint OK"
```
| Line | Meaning |
|---|---|
| `<<'EOF'` (quoted) | Bash writes `${{ … }}` as-is for GitHub |
| `on: push: branches: [labs]` | Runs when something **lands on `labs`** (= a merge). PRs never trigger it, so a PR can't push images. |
| `paths: [day08/**, the workflow]` | Only when the app or this file changes |
| `workflow_dispatch:` | Manual button; runs on `labs`, so `sub` still matches |
| `permissions: id-token: write` | **The key line** — may request an OIDC token |
| `configure-aws-credentials@v6.3.0` | Gets the token, calls `AssumeRoleWithWebIdentity`, exports temporary keys to later steps |
| `role-to-assume: ${{ vars.AWS_ROLE_ARN }}` | The ARN from the repo variable |
| `aws sts get-caller-identity` | Proof: an **assumed role**, not a user |
| `amazon-ecr-login@v2.1.7` · `id: ecr` | `docker login` to ECR; outputs `registry` = `<id>.dkr.ecr.us-east-1.amazonaws.com` |
| `IMAGE: …/capstone:${{ github.sha }}` | Tag = the commit SHA |
| `docker build -t "$IMAGE" day08` | The Day 8 app — already linted, tested and Trivy-clean |
| `docker push "$IMAGE"` | Upload to ECR |

> With `IMMUTABLE` tags, re-running on the **same** commit fails with `tag … already exists` — correct: one SHA, one image.

### 5.3 Commit only the workflow, open the PR
```bash
git add .github/workflows/day09-push.yml
git status --short
git commit -m "ci(day09): push day08 image to ECR via GitHub OIDC (no AWS keys)"
git push -u origin lab/day09-ecr-push
gh pr create --base labs --head lab/day09-ecr-push \
  --title "ci(day09): push image to ECR with OIDC" \
  --body "Day 9 lab: on merge into labs, assume role gha-ecr-push via GitHub OIDC and push day08 image to ECR as capstone:<git-sha>. Role ARN comes from repo variable AWS_ROLE_ARN; no AWS secrets in GitHub."
gh pr checks 18 --watch
```
| Command | Meaning |
|---|---|
| `git add <one file>` | Only the workflow — local scratch files stay untracked |
| `gh pr create --base labs` | **PR #18** |
| `gh pr checks 18 --watch` | The 3 **required** Day 8 checks pass. `Day 9 push to ECR` does **not** run on a PR. (Run right after creating the PR it says `no checks reported` — just timing.) |

### 5.4 Merge = the trigger
```bash
gh pr merge 18 --squash --delete-branch
git switch labs && git pull
RUN_ID=$(gh run list --workflow day09-push.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```
| Command | Meaning |
|---|---|
| `gh pr merge 18 --squash` | One commit `ec0a5a6f` lands on `labs` → a `push` event touching the workflow file → the run starts |
| `gh run watch … --exit-status` | Run `44100642563`: ✅ success in **32 s** |

---

## Part 6 — Prove it

```bash
aws ecr list-images --repository-name capstone
git log -1 --format='%H %s'
gh run view "$RUN_ID" --log | grep -E 'assumed-role|pushed ' | sed -E 's/[0-9]{12}/<id>/g'
gh secret list
aws ecr describe-images --repository-name capstone --query 'imageDetails[].[imageTags[0],imageSizeInBytes,imageScanStatus.status]' --output table
```
| Check | Result |
|---|---|
| `list-images` | tag `ec0a5a6f7eafc1cc28e72ef6fa93a4f4db41b523`, digest `sha256:91e99e4e…` |
| `git log -1` | `ec0a5a6f7eafc1cc28e72ef6fa93a4f4db41b523 ci(day09): … (#18)` — **same SHA as the tag** |
| run log | `arn:aws:sts::<id>:assumed-role/gha-ecr-push/GitHubActions` and `pushed <id>.dkr.ecr.us-east-1.amazonaws.com/capstone:ec0a5a6f…` |
| `gh secret list` | `no secrets found` |
| `describe-images` | `28685478` bytes ≈ **27 MB** (compressed layers; ~120 MB unpacked locally) |
| scan status | `None` — the repo-level `scanOnPush` is overridden by ECR's **registry-level** scanning setting. Fine here: Trivy already scanned the image in CI. Don't enable **Enhanced** scanning (Amazon Inspector, paid). |

### What the image contains
| Layer | Contents |
|---|---|
| Base | Alpine Linux + Python 3.12 (`python:3.12-alpine`) |
| Patches + user | `apk upgrade`; user `app` (uid 10001) |
| Libraries | `/opt/venv`: `fastapi==0.163.1`, `uvicorn==0.54.0` (from the builder stage) |
| Code | `/app/app/__init__.py` (empty) + `/app/app/main.py` (`/health`, `GET/POST /items`, in-memory) |
| Metadata | `USER app`, `EXPOSE 8000`, `HEALTHCHECK /health`, `CMD uvicorn app.main:app` |

Not inside: tests, `.env`, compose, README, requirements files, any key.

### Review in the console (as `DevOps`, region **us-east-1**)
| Where | What you see |
|---|---|
| ECR → Private registry → Repositories → `capstone` | The image, its tag, size, push time; Lifecycle Policy; Immutable, AES-256 |
| IAM → Identity providers | `token.actions.githubusercontent.com`, audience `sts.amazonaws.com` |
| IAM → Roles → `gha-ecr-push` | Trust relationships (`aud` + `sub`), Permissions (`ecr-push-capstone`), Last activity |
| CloudTrail → Event history | `AssumeRoleWithWebIdentity` and `PutImage` by `GitHubActions` |

> ECR is **regional**: in another region (e.g. Stockholm) the list is empty. IAM is **global**.

### Stored ≠ deployed
The image is **stored** in ECR; nothing **runs** it yet. A later day pulls it onto compute (EC2, ECS, Kubernetes) — that's CD.

---

## What stays (kept on purpose)

| Resource | Cost | Why keep it |
|---|---|---|
| OIDC provider | $0 | Reused by any future role |
| Role `gha-ecr-push` + inline policy | $0 | The pipeline uses it on every merge that touches `day08/` |
| ECR repo `capstone` (1 image, lifecycle keeps 1) | ≈ $0.003/month | Later deploy days pull this image |
| Repo variable `AWS_ROLE_ARN` | $0 | Read by the workflow |

### Teardown (when the sprint is over)
```bash
aws ecr delete-repository --repository-name capstone --force
aws iam delete-role-policy --role-name gha-ecr-push --policy-name ecr-push-capstone
aws iam delete-role --role-name gha-ecr-push
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
gh variable delete AWS_ROLE_ARN
gh workflow disable day09-push.yml
```
| Command | Meaning |
|---|---|
| `delete-repository … --force` | Delete the repo **and** its images |
| `delete-role-policy` → `delete-role` | A role's inline policies must go first |
| `delete-open-id-connect-provider` | Remove the provider |
| `gh variable delete` / `gh workflow disable` | Clean up GitHub so later merges don't fail |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `sub` or `aud` in the token ≠ trust policy (wrong branch, old `repo:owner/repo` form, PR event) | Print the real claims (Part 0) and compare character by character |
| `Credentials could not be loaded` / no `ACTIONS_ID_TOKEN_REQUEST_URL` | Missing `permissions: id-token: write` | Add it at workflow or job level |
| `role-to-assume` is empty | Variable not set, or `secrets.` used instead of `vars.` | `gh variable list`; use `${{ vars.AWS_ROLE_ARN }}` |
| `AccessDenied … ecr:InitiateLayerUpload` | Permissions policy misses an action, or wrong repo ARN/region | Check `get-role-policy`; ARN must be `…:us-east-1:<id>:repository/capstone` |
| `tag invalid: … already exists` | `IMMUTABLE` + re-run on the same commit | Expected; push a new commit |
| Console shows no repositories | Wrong region selected | Switch to **US East (N. Virginia)** |
| `no checks reported` right after `gh pr create` | Workflows haven't started yet | Wait ~10 s, run `gh pr checks <n> --watch` again |

## Commands to remember
| Goal | Command |
|---|---|
| Who am I | `aws sts get-caller-identity --query Arn --output text` |
| The exact `sub` for a branch | `gh api repos/<owner>/<repo> --jq '"repo:\(.owner.login)@\(.owner.id)/\(.name)@\(.id):ref:refs/heads/<branch>"'` |
| The role's trust conditions | `aws iam get-role --role-name gha-ecr-push --query 'Role.AssumeRolePolicyDocument'` |
| Images in ECR | `aws ecr describe-images --repository-name capstone --output table` |
| Pull locally | `aws ecr get-login-password \| docker login --username AWS --password-stdin <registry>` then `docker pull <registry>/capstone:<sha>` |
| Latest push run | `gh run list --workflow day09-push.yml --limit 1` |
| Prove no secrets | `gh secret list` |
