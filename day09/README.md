[⬅ Back to index](../README.md)

# Day 9 — IAM for Pipelines and ECR (Week 2 · Day 4)

**Date:** 2026-11-17
**Topic:** IAM for pipelines — roles vs users, least privilege, OIDC federation, ECR
**Reading:** [IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) · [GitHub: OpenID Connect in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) · [configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials) · [What is Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)
**Cost:** IAM, OIDC and STS are free; ECR storage $0.10 per GB-month (one small image ≈ $0.003/month); data in is free.
**Lab:** create a GitHub OIDC provider and a role trusted only by your repo and branch. On merge, push the image to ECR tagged with the git SHA. No access keys in GitHub secrets.

| Part | Content |
|---|---|
| 📖 Cheat sheet | Policy elements, OIDC claims, CLI commands at a glance |
| Sections A–F | Definitions with examples |
| Check-your-understanding answers | All sections |
| Key takeaways | What to remember |

---

## 📖 Cheat sheet

### Policy JSON elements
| Element | Meaning | Example |
|---|---|---|
| `Version` | Policy language version — always this date | `"2012-10-17"` |
| `Statement` | A list of rules | `[ { … }, { … } ]` |
| `Sid` | Optional label for a statement | `"PushToCapstoneOnly"` |
| `Effect` | `Allow` or `Deny` | `"Allow"` |
| `Principal` | **Who** (only in trust / resource policies) | `{ "Federated": "arn:aws:iam::<id>:oidc-provider/…" }` |
| `Action` | **What** API calls | `"ecr:PutImage"`, `"s3:GetObject"` |
| `Resource` | **On which** resources (ARNs) | `"arn:aws:ecr:us-east-1:<id>:repository/capstone"` |
| `Condition` | **Only if** … | `"StringEquals": { "…:sub": "repo:…:ref:refs/heads/labs" }` |

### GitHub OIDC token claims
| Claim | Meaning | Example |
|---|---|---|
| `iss` | Issuer — who signed it | `https://token.actions.githubusercontent.com` |
| `aud` | Audience — who it's for | `sts.amazonaws.com` |
| `sub` | Subject — which repo / branch / event | `repo:wisamMu@66379795/Devops-Sprint-Wisam@1443987341:ref:refs/heads/labs` |
| `repository_id`, `repository_owner_id` | Numeric IDs (never change) | `1443987341`, `66379795` |
| `ref`, `sha`, `event_name` | Branch, commit, trigger | `refs/heads/labs`, `ec0a5a6f…`, `push` |
| `iat`, `exp` | Issued at / expires | 5 minutes apart |

### Commands
| Goal | Command |
|---|---|
| Who am I | `aws sts get-caller-identity` |
| Use a profile | `export AWS_PROFILE=sprint2` |
| OIDC providers | `aws iam list-open-id-connect-providers` |
| A role's trust policy | `aws iam get-role --role-name <r> --query Role.AssumeRolePolicyDocument` |
| A role's inline policies | `aws iam list-role-policies --role-name <r>` |
| ECR repos / images | `aws ecr describe-repositories` · `aws ecr describe-images --repository-name <r>` |
| Docker login to ECR | `aws ecr get-login-password \| docker login --username AWS --password-stdin <id>.dkr.ecr.<region>.amazonaws.com` |
| GitHub variables / secrets | `gh variable list` · `gh secret list` |

---

## A — Users vs roles

| Term | Definition | Example |
|---|---|---|
| **IAM** | Identity and Access Management: who can do what in an AWS account. Global, free. | Users, roles, policies |
| **Principal** | Anything that can make a request to AWS. | A user, a role session, an AWS service |
| **Root user** | The account owner (email login). Can do everything, even close the account. Use only for root-only tasks; MFA on. | Turning on IAM access to billing |
| **IAM user** | A person or app with **long-term** credentials: a password and/or **access keys**. | `DevOps` (console + `aws login`) |
| **Access keys** | `AKIA…` key ID + secret key. Valid **until deleted** → dangerous if leaked. | Old way to give CI access — avoided here |
| **IAM role** | An identity with **no** credentials of its own. Someone **assumes** it and gets **temporary** keys. | `gha-ecr-push` |
| **STS** | Security Token Service — hands out temporary credentials. | `AssumeRole`, `AssumeRoleWithWebIdentity` |
| **Temporary credentials** | Key ID (`ASIA…`) + secret + **session token**; expire (15 min – 12 h). | 1 h for the pipeline |
| **Assume a role** | Ask STS "let me act as this role" → temporary keys. | GitHub becomes `gha-ecr-push` |
| **Profile** | A named set of CLI settings in `~/.aws/config`. | `default` (old account), `sprint2` |

| | User | Role |
|---|---|---|
| Credentials | Long-term (password, access keys) | Temporary, from STS |
| Who uses it | One person / app | Whoever the trust policy allows |
| If leaked | Works until someone deletes it | Expires on its own |
| For pipelines | ❌ keys in CI secrets | ✅ OIDC → role |

---

## B — Least privilege

| Term | Definition | Example |
|---|---|---|
| **Least privilege** | Grant only the actions and resources a job needs — nothing more. | Push to `capstone` only, no pull, no delete |
| **Scope by action** | List exact actions, not `ecr:*`. | 5 push actions + login |
| **Scope by resource** | Use the resource's ARN, not `*`. | `…:repository/capstone` |
| **Scope by condition** | Extra checks on the request. | `sub` = this repo, `labs` only |
| **Separate roles per job** | One pipeline task = one role. | `gha-ecr-push` (push), later a deploy role |
| **Blast radius** | What an attacker could do with stolen access. | Stolen role keys: push one image for ≤ 1 h |

### IAM best practices (headlines)
| Practice | Meaning |
|---|---|
| Use temporary credentials | Roles and federation (OIDC, `aws login`) instead of long-term access keys |
| Require MFA | On root and on human users |
| Don't use root daily | Lock it away after setup |
| Rotate / remove unused keys | Ideally: no access keys at all |
| Grant least privilege | Start small, add what is proven needed |
| Use conditions | Limit by repo, branch, IP, MFA, … |
| Review unused access | IAM "Last activity", Access Analyzer |

---

## C — Policies

| Term | Definition | Example |
|---|---|---|
| **Policy** | A JSON document that allows or denies actions. | `ecr-push-capstone` |
| **Identity-based policy** | Attached to a user/group/role: what **it** may do. | Permissions policy of `gha-ecr-push` |
| **Resource-based policy** | Attached to a resource: **who** may use it. | S3 bucket policy, ECR repository policy |
| **Trust policy** | The role's resource-based policy: **who may assume** the role. | GitHub OIDC, repo + `labs` |
| **Permissions policy** | What the role may do after it's assumed. | Push to `capstone` |
| **AWS managed policy** | Written by AWS, shared, broad. | `AdministratorAccess` |
| **Customer managed policy** | Written by you, reusable across identities. | — |
| **Inline policy** | Embedded in one identity; deleted with it. | `ecr-push-capstone` |
| **ARN** | Amazon Resource Name — unique address: `arn:partition:service:region:account:resource`. | `arn:aws:iam::<id>:role/gha-ecr-push` (IAM is global → empty region) |
| **Condition key** | A value AWS checks in `Condition`. | `token.actions.githubusercontent.com:sub` |

### How AWS decides
| Rule | Meaning |
|---|---|
| Default = **implicit deny** | Nothing is allowed unless a policy allows it |
| An **Allow** opens access | If no deny applies |
| An **explicit Deny** always wins | Over any number of allows |

### Two policies on one role
```text
Trust policy (who may become it)          Permissions policy (what it may do)
──────────────────────────────            ───────────────────────────────────
Principal: GitHub OIDC provider           ecr:GetAuthorizationToken  on *
Action:    sts:AssumeRoleWithWebIdentity  ecr:…LayerUpload, PutImage on repository/capstone
Condition: aud = sts.amazonaws.com
           sub = repo:…@1443987341:ref:refs/heads/labs
```

---

## D — OIDC federation

| Term | Definition | Example |
|---|---|---|
| **Federation** | Trust an outside identity system instead of creating IAM users. | GitHub identities → AWS role |
| **OIDC (OpenID Connect)** | A standard for proving identity with signed tokens. | GitHub Actions ↔ AWS STS |
| **Identity provider (IdP)** | The system that issues the tokens. | `token.actions.githubusercontent.com` |
| **OIDC provider (in IAM)** | AWS's record of an IdP it trusts: URL + audience. Trusts **GitHub Actions in general**, not one repo. | `arn:aws:iam::<id>:oidc-provider/token.actions.githubusercontent.com` |
| **JWT** | JSON Web Token: `header.payload.signature`, Base64url-encoded. | The OIDC token |
| **Claims** | The fields in the payload. | `iss`, `aud`, `sub`, `exp` |
| **Signature (RS256)** | GitHub signs with its private key; AWS checks with GitHub's public keys (**JWKS**). | A changed claim → invalid signature |
| **`id-token: write`** | Workflow permission to request a token. Gives the job `ACTIONS_ID_TOKEN_REQUEST_URL` + `_TOKEN`. | `permissions: { id-token: write }` |
| **`AssumeRoleWithWebIdentity`** | STS call: token + role ARN → temporary keys. | Done by `configure-aws-credentials` |
| **Immutable `sub`** | Newer repos use `repo:owner@ownerId/repo@repoId:…` — a renamed or re-created repo can't match. | `repo:wisamMu@66379795/Devops-Sprint-Wisam@1443987341:…` |

### `sub` formats
| Workflow ran from | `sub` ends with |
|---|---|
| Push to a branch | `:ref:refs/heads/<branch>` |
| A tag | `:ref:refs/tags/<tag>` |
| A pull request | `:pull_request` |
| A job with `environment: prod` | `:environment:prod` |

### The flow
```text
1. Workflow (id-token: write) asks GitHub for a token  → JWT, aud = sts.amazonaws.com, lives 5 min
2. Sends it to STS: AssumeRoleWithWebIdentity(role ARN, JWT)
3. STS checks: signature (OIDC provider + GitHub's JWKS), then aud/sub (role trust policy)
4. STS returns temporary keys (1 h)  → the job acts as the role
5. Keys expire. Nothing was stored anywhere.
```

| Why OIDC beats access keys | |
|---|---|
| No secret to store, rotate or leak | The repo has **0 secrets** |
| Short-lived | Token 5 min, keys ≤ 1 h |
| Bound to repo + branch | A fork, another repo or branch is refused |
| Auditable | CloudTrail shows `AssumeRoleWithWebIdentity` + session name |

---

## E — `aws-actions/configure-aws-credentials`

| Term | Definition | Example |
|---|---|---|
| **The action** | Official AWS action that gets credentials for later steps. With `role-to-assume` + `id-token: write` it uses OIDC. | `aws-actions/configure-aws-credentials@v6.3.0` |
| `role-to-assume` | The role ARN. | `${{ vars.AWS_ROLE_ARN }}` |
| `aws-region` | Default region for later steps. | `us-east-1` |
| `role-session-name` | Name shown in CloudTrail / `get-caller-identity`. Default `GitHubActions`. | `assumed-role/gha-ecr-push/GitHubActions` |
| `role-duration-seconds` | How long the keys live (≤ the role's max). Default 1 h. | `3600` |
| `audience` | The `aud` to request. Default `sts.amazonaws.com`. | — |
| **What it outputs** | Exports `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION` (masked) to later steps. | `aws …` and `docker` just work |
| **Variable vs secret** | The role ARN is an **address**, not a secret → a repo **variable**. | `gh variable set AWS_ROLE_ARN` |

```yaml
permissions:
  contents: read
  id-token: write            # required for OIDC
steps:
  - uses: aws-actions/configure-aws-credentials@v6.3.0
    with:
      role-to-assume: ${{ vars.AWS_ROLE_ARN }}
      aws-region: us-east-1
  - run: aws sts get-caller-identity   # → assumed-role/gha-ecr-push/GitHubActions
```

---

## F — Amazon ECR

| Term | Definition | Example |
|---|---|---|
| **ECR** | Elastic Container Registry — AWS's private Docker image registry. **Stores** images; it never **runs** them. Regional. | `us-east-1` |
| **Registry** | One per account per region; exists automatically. | `<id>.dkr.ecr.us-east-1.amazonaws.com` |
| **Repository** | A named shelf for one image's versions. | `capstone` |
| **Image tag** | A label for one version. | `ec0a5a6f…` (git SHA) |
| **Digest** | `sha256:` fingerprint of the content — same content, same digest. | `sha256:91e99e4e…` |
| **Repository URI** | The address Docker uses. | `<id>.dkr.ecr.us-east-1.amazonaws.com/capstone` |
| **Repository ARN** | The address IAM uses. | `arn:aws:ecr:us-east-1:<id>:repository/capstone` |
| **Login** | Docker needs a 12 h password from `ecr:GetAuthorizationToken`. | `aws ecr get-login-password \| docker login …` · in CI: `amazon-ecr-login` |
| **Tag immutability** | `IMMUTABLE` = a tag can't be overwritten. | One SHA = one image |
| **Lifecycle policy** | Rules that expire old images automatically (within ~24 h). | Keep only the newest 1 |
| **Scanning** | Basic (free, CVEs in OS packages) or Enhanced (Amazon Inspector, **paid**). Registry-level settings override repo-level `scanOnPush`. | Our scan: Trivy in CI |
| **Encryption** | `AES256` (AWS-owned key, free) or `KMS` (customer key, paid). | `AES256` |
| **Pricing** | Storage $0.10/GB-month; data in free; data out to the internet, first 100 GB/month free. | 27 MB ≈ $0.003/month |

### Push permissions
| Action | Step of `docker push` |
|---|---|
| `ecr:GetAuthorizationToken` | Login (registry-wide → `Resource: *`) |
| `ecr:BatchCheckLayerAvailability` | Which layers already exist? |
| `ecr:InitiateLayerUpload` / `UploadLayerPart` / `CompleteLayerUpload` | Upload a new layer |
| `ecr:PutImage` | Write manifest + tag |
| *(pull would add)* `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer` | Not granted — push-only role |

### Stored → running
```text
CI builds → push to ECR (stored)  → compute pulls it → container runs → users call it
                Day 9                 EC2 / ECS / Kubernetes (later days)
```

---

## Check-your-understanding answers

| § | Question | Answer |
|---|---|---|
| A | User vs role? | User: long-term credentials for one identity. Role: no credentials; assumed for temporary keys. |
| A | Why not access keys in CI secrets? | Long-lived, can leak via logs/forks, must be rotated by hand. |
| A | What does STS return? | Key ID + secret + session token, with an expiry. |
| A | `ASIA…` vs `AKIA…`? | Temporary (STS) vs long-term access key. |
| B | `ecr:*` on `*` for the pipeline? | Works, but the pipeline could delete every repo — not least privilege. |
| B | Why can't `GetAuthorizationToken` be limited to one repo? | The login is for the whole registry. |
| C | Trust vs permissions policy? | Who may assume the role vs what it may do. |
| C | Allow + explicit Deny on the same action? | Deny wins. |
| C | No policy mentions an action? | Implicit deny. |
| C | Why is the IAM ARN's region empty? | IAM is global. |
| D | Which claims does the trust policy check? | `aud` and `sub`. |
| D | Does the OIDC provider let any repo in? | It lets nobody in on its own; the role's `sub` condition picks the repo + branch. |
| D | `sub` of a PR run? | `repo:…:pull_request` — so it doesn't match a `refs/heads/labs` rule. |
| D | Why the `@ids` form? | Rename/re-create attacks can't match a numeric ID. |
| D | What happens without `id-token: write`? | No token can be requested → credentials step fails. |
| E | Where does the role ARN go? | A repo variable, `${{ vars.AWS_ROLE_ARN }}`. |
| E | How do later steps get the keys? | The action exports them as masked env vars. |
| F | ECR runs containers? | No — it only stores images. |
| F | URI vs ARN? | Docker address vs IAM address. |
| F | Re-run on the same SHA with IMMUTABLE? | Push fails: the tag already exists. |
| F | Console shows no repos? | Check the region. |

---

## Key takeaways

| Topic | Remember |
|---|---|
| Pipelines | Use **roles**, never access keys |
| Least privilege | Exact actions + resource ARNs + conditions |
| Two policies | Trust = who; permissions = what |
| OIDC | `id-token: write` → JWT → `AssumeRoleWithWebIdentity` → 1 h keys |
| Provider vs role | Provider trusts GitHub Actions; role's `sub` trusts **your repo + branch** |
| `sub` | Exact match; immutable `@ids` form; branch/PR/env change it |
| ARN in GitHub | A **variable**, not a secret — nothing secret is stored |
| ECR | Regional registry; URI for Docker, ARN for IAM; tag = git SHA; IMMUTABLE; lifecycle rules |
| Cost | IAM/OIDC/STS free; avoid KMS keys and Enhanced scanning |
