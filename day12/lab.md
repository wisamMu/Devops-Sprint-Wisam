# Day 12 Lab — Terraform for Teams: S3 State, Modules, Imports, CI Plan

**The task (sprint plan):** Terraform for teams: S3 remote state with native locking (`use_lockfile`), modules, data sources, `fmt` / `validate` / `tflint`. **Lab:** move state to S3, refactor the network into a local module and add the ECR repo and IAM roles to code. On PR, CI runs `fmt -check`, `validate` and `plan`.

**Date:** 2026-11-28 · **Where:** WSL Ubuntu 24.04 + AWS CLI (profile `sprint2`, `us-east-1`)
**Versions:** Terraform v1.17.2 · AWS provider 6.x · tflint v0.66.0 · tflint AWS ruleset 0.50.0 · `hashicorp/setup-terraform@v4.0.1`
**Cost:** $0 (a VPC and a subnet are free; the state file costs well under $0.01/month)
**Result:** state in S3 with locking; the network moved into a module with **0 destroy**; ECR `hello-web` and role `ec2-hello` imported, role `gha-tf-plan` created; tflint clean; PR #32: CI plan said `No changes`, account ID masked (0 hits).

> No sensitive values in this file: the account ID is `<ACCOUNT_ID>`, the bucket is `devops-sprint-tfstate-<ACCOUNT_ID>`, resource IDs are `vpc-0…`. The bucket name lives only in the git-ignored `backend.hcl` and in a GitHub secret.

| Requirement | Result |
|---|---|
| S3 remote state + native locking | ✅ `backend "s3"` with `use_lockfile = true`; state at `day12/terraform.tfstate` |
| Refactor the network into a local module | ✅ `modules/network`; 2 `moved` blocks → `0 to add, 0 to change, 0 to destroy` |
| Data sources | ✅ `aws_availability_zones` (module), `aws_iam_openid_connect_provider` (CI role) |
| ECR repo + IAM roles in code | ✅ imported `hello-web` + `ec2-hello`; new `gha-tf-plan` |
| `fmt` / `validate` / `tflint` | ✅ all clean (after adding `modules/network/versions.tf`) |
| CI on PR: `fmt -check`, `validate`, `plan` | ✅ PR #32 green, plan `No changes` |

```text
day12/
├── backend.tf          backend "s3" { key, region, encrypt, use_lockfile }   (bucket comes from backend.hcl)
├── backend.hcl         bucket = "…"   (git-ignored)
├── providers.tf        terraform + aws provider + default_tags
├── variables.tf        aws_region, vpc_cidr, subnet_cidr
├── main.tf             module "network" { source = "./modules/network" }
├── moved.tf            aws_vpc.main / aws_subnet.main → module.network.…
├── imported.tf         aws_ecr_repository.hello_web, aws_iam_role.ec2_hello
├── iam_ci.tf           data OIDC provider + role gha-tf-plan + ReadOnlyAccess
├── outputs.tf          module.network.vpc_id / subnet_id / availability_zone
├── .tflint.hcl         terraform (recommended) + aws plugin 0.50.0
└── modules/network/    main.tf (data AZs + VPC + subnet), variables.tf, outputs.tf, versions.tf

.github/workflows/day12-terraform.yml   on: pull_request → init, fmt -check, validate, plan -lock=false
```

---

## S1 — tflint, branch, starting files

### Install tflint v0.66.0 (the old `install_linux.sh` script returns 404)
```bash
cd /tmp
```
```bash
curl -fsSLO https://github.com/terraform-linters/tflint/releases/download/v0.66.0/tflint_linux_amd64.zip
```
```bash
curl -fsSLO https://github.com/terraform-linters/tflint/releases/download/v0.66.0/checksums.txt
```
```bash
sha256sum --check --ignore-missing checksums.txt
```
```bash
unzip -o tflint_linux_amd64.zip
```
```bash
sudo install -m 755 tflint /usr/local/bin/tflint
```
```bash
tflint --version
```
```bash
rm tflint tflint_linux_amd64.zip checksums.txt
```

| Package / file | What it's for |
|---|---|
| `tflint` v0.66.0 → `/usr/local/bin/tflint` | Terraform linter: real mistakes and best practices that `validate` doesn't catch |
| `checksums.txt` + `sha256sum --check` | Proves the download is genuine and complete (`tflint_linux_amd64.zip: OK`) |
| AWS ruleset 0.50.0 → `~/.tflint.d/plugins/` | Installed later by `tflint --init` (S7) |

### Branch and the starting code
```bash
cd ~/Devops-Sprint-Wisam
```
```bash
git switch labs && git pull
```
```bash
git switch -c lab/day12-terraform
```
```bash
mkdir -p day12 && cd day12
```

Files written with `cat > FILE <<'EOF' … EOF`: `providers.tf` (Terraform `>= 1.10` for `use_lockfile`, AWS `~> 6.0`, `default_tags` with `App = "day12"`), `variables.tf`, `vpc.tf` (one VPC `10.50.0.0/16` + one subnet `10.50.1.0/24`), `outputs.tf`, `.gitignore`.

| Simplification | Why |
|---|---|
| Only a VPC + subnet | No EC2 on Day 12, so no IGW, routes or SG are needed. Enough to move into a module, and free |
| No `my_ip` variable | Nothing uses an IP, so no `terraform.tfvars` and no IP secret in CI |

```bash
terraform fmt -check && echo "fmt OK"
```

---

## S2 — The state bucket (CLI, once)

Terraform can't keep its state in a bucket that doesn't exist yet, so the bucket is made by hand.

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION
```
```bash
aws login --profile sprint2
```
```bash
export AWS_PROFILE=sprint2 AWS_REGION=us-east-1
```
```bash
ACCT=$(aws sts get-caller-identity --query Account --output text)
```
```bash
BUCKET="devops-sprint-tfstate-$ACCT"
```
```bash
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region us-east-1
```
```bash
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
```
```bash
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

| Check | Result |
|---|---|
| `get-bucket-versioning` | `Enabled` — every save of the state keeps the old version |
| `get-public-access-block` | 4 × `True` |
| `get-bucket-encryption` | `AES256` (SSE-S3, on by default) |

---

## S3 — Build with local state

```bash
eval "$(aws configure export-credentials \
  --profile sprint2 \
  --format env)"
```
```bash
terraform init
```
```bash
terraform validate
```
```bash
terraform plan \
  -out=day12.tfplan
```
```bash
terraform apply day12.tfplan
```

Result: `Apply complete! Resources: 2 added`. The state was a local `terraform.tfstate` file.

---

## S4 — Move the state to S3 (with locking)

```bash
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {
    key          = "day12/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
EOF
```
```bash
echo "bucket = \"$BUCKET\"" > backend.hcl
```
```bash
git check-ignore backend.hcl && echo "ignored: good"
```
```bash
terraform init \
  -backend-config=backend.hcl \
  -migrate-state
```
```bash
aws s3 ls "s3://$BUCKET/day12/"
```
```bash
terraform plan
```
```bash
rm -f terraform.tfstate terraform.tfstate.backup
```

| Part | Meaning |
|---|---|
| `backend "s3"` | Terraform keyword: keep the state in S3 (the file name is free; first named `memorystate.tf`, then back to the convention `backend.tf`) |
| `use_lockfile = true` | While a command runs, Terraform writes `day12/terraform.tfstate.tflock` next to the state; a second run is refused. Terraform ≥ 1.10, no DynamoDB |
| No `bucket` in `backend.tf` | **Partial configuration**: the bucket name (account ID) comes from git-ignored `backend.hcl` |
| `init` again | A new backend must be initialised |
| `-migrate-state` | Copies the existing local state **into** S3 (answer `yes`) |
| Result | `terraform.tfstate` in S3; `plan` → `No changes`; local copy empty and removed |

**What lives where:** the **state** (resources, IDs, outputs) is in S3. The **settings** (`backend.tf`, `backend.hcl`) stay in the folder. `init` keeps a small note in `.terraform/terraform.tfstate` ("this folder uses that S3 backend"), which is not the state.

---

## S5 — Network into a local module + a data source

```bash
rm -f terraform.tfstate terraform.tfstate.backup day12.tfplan
```
```bash
mkdir -p modules/network
```

- `modules/network/variables.tf` — inputs `name`, `vpc_cidr`, `subnet_cidr` (no defaults)
- `modules/network/main.tf` — `data "aws_availability_zones" "available" { state = "available" }`, the VPC, and the subnet with `availability_zone = data.aws_availability_zones.available.names[0]`
- `modules/network/outputs.tf` — `vpc_id`, `subnet_id`, `availability_zone`
- `main.tf` — `module "network" { source = "./modules/network" … }`
- `moved.tf`:

```hcl
moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}

moved {
  from = aws_subnet.main
  to   = module.network.aws_subnet.main
}
```

```bash
rm vpc.tf
```
```bash
terraform fmt -check -recursive && echo "fmt OK"
```
```bash
terraform get
```
```bash
terraform validate
```
```bash
terraform plan
```
```bash
terraform apply
```
```bash
terraform state list
```

| Check | Result |
|---|---|
| `plan` | `aws_vpc.main has moved to module.network.aws_vpc.main` (and the subnet) · `Plan: 0 to add, 0 to change, 0 to destroy.` |
| `state list` | `module.network.aws_vpc.main`, `module.network.aws_subnet.main`, `module.network.data.aws_availability_zones.available` |

| Idea | Meaning |
|---|---|
| Module | A reusable folder: variables = inputs, resources = work, outputs = results |
| `module.network.vpc_id` | The root can only reach what the module **outputs** |
| `moved` | Only the address changed → rename in the state instead of destroy + create |
| `terraform get` | Registers a new module without touching the backend |

---

## S6 — ECR repo and IAM roles in code

```bash
cat > imports.tf <<'EOF'
import {
  to = aws_ecr_repository.hello_web
  id = "hello-web"
}

import {
  to = aws_iam_role.ec2_hello
  id = "ec2-hello"
}
EOF
```

- `imported.tf` — `aws_ecr_repository.hello_web` (`IMMUTABLE`) and `aws_iam_role.ec2_hello` (trust: `ec2.amazonaws.com`), both tagged `App = "hello-web"`
- `iam_ci.tf` — `data "aws_iam_openid_connect_provider" "github"`, role `gha-tf-plan` trusted only for `repo:…/Devops-Sprint-Wisam@…:pull_request`, plus `ReadOnlyAccess`

```bash
terraform plan
```
```bash
terraform apply
```
```bash
rm imports.tf
```
```bash
terraform plan
```

| Check | Result |
|---|---|
| `plan` | `2 to import, 2 to add`, changes on tags only, `0 to destroy` |
| After `rm imports.tf` | `No changes.` — import blocks are one-time; the state now holds the resources |

| Why not `-generate-config-out` as-is | |
|---|---|
| Tried it first | It wrote read-only values (`arn`, `id`, `unique_id`, `tags_all` …) → **planning failed** |
| Deprecated `inline_policy` blocks | Warnings, and Terraform would take over the inline policies |
| **The account ID hard-coded 7 times** | Not acceptable in a public repo → wrote a short clean version instead; the OIDC ARN comes from a data source |

---

## S7 — fmt / validate / tflint

```bash
cat > .tflint.hcl <<'EOF'
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
EOF
```
```bash
tflint --init
```
```bash
terraform fmt -check -recursive && echo "fmt OK"
```
```bash
terraform validate
```
```bash
tflint --recursive --config "$(pwd)/.tflint.hcl"
```

| Finding | Fix |
|---|---|
| `terraform_required_version` / `terraform_required_providers` in `modules/network` | Added `modules/network/versions.tf` (`required_version >= 1.10`, `aws ~> 6.0`) |
| After the fix | No issues; `terraform plan` → `No changes` |

| Tool | Catches |
|---|---|
| `fmt -check` | Formatting |
| `validate` | Invalid Terraform (references, types) |
| `tflint` | Unused declarations, missing versions, invalid AWS values |

---

## S8 — CI on pull requests

```yaml
name: day12 terraform

on: pull_request

permissions:
  contents: read
  id-token: write

jobs:
  terraform:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7

      - uses: hashicorp/setup-terraform@v4.0.1

      - uses: aws-actions/configure-aws-credentials@v6.3.0
        with:
          role-to-assume: ${{ secrets.TF_PLAN_ROLE_ARN }}
          aws-region: us-east-1
          mask-aws-account-id: true

      - name: fmt, validate, plan
        working-directory: day12
        run: |
          terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}"
          terraform fmt -check -recursive
          terraform validate
          terraform plan -lock=false
```

```bash
cd ~/Devops-Sprint-Wisam
```
```bash
gh secret set TF_PLAN_ROLE_ARN \
  --body "$(aws iam get-role --role-name gha-tf-plan --query Role.Arn --output text --profile sprint2)"
```
```bash
VAL=$(sed -n 's/^bucket *= *"\(.*\)"/\1/p' day12/backend.hcl)
```
```bash
echo "${#VAL} characters"
```
```bash
gh secret set TF_STATE_BUCKET --body "$VAL"
```
```bash
git add day12 .github/workflows/day12-terraform.yml
```
```bash
git status --short
```
```bash
git commit -m "feat(day12): S3 remote state, network module, ECR + IAM in code, CI plan on PR"
```
```bash
git push -u origin lab/day12-terraform
```
```bash
gh pr create \
  --base labs \
  --title "Day 12: Terraform for teams" \
  --body "State in S3 with use_lockfile, network as a local module with a data source, ECR + IAM roles in code, CI runs fmt -check, validate and plan on PRs."
```
```bash
gh pr checks --watch
```
```bash
gh pr merge 32 \
  --squash \
  --delete-branch
```

| Check | Result |
|---|---|
| PR #32 checks | `terraform`, `lint (ruff)`, `test (pytest)`, `build + scan` all pass |
| CI plan | `No changes. Your infrastructure matches the configuration.` — a fresh runner read the same state from S3 |
| Account ID in the run log | 0 hits (`***`) |
| `git status` before commit | No `backend.hcl`, `.terraform/`, `*.tfstate`, `*.tfplan` |

---

## Problems we hit

| Problem | Cause | Fix |
|---|---|---|
| `install_linux.sh` → `curl: (22) … 404` | tflint removed its install script | Download the release zip, check `checksums.txt`, `install` the binary |
| `Credentials were refreshed, but … still expired` / `ExpiredToken` | Exported keys from `export-credentials` expire after ~1 hour and override `aws login` | `unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION`, then `aws login` / `eval` again |
| `-generate-config-out` → planning failed | Generated draft had read-only values, deprecated `inline_policy` and the account ID | Wrote a short clean `imported.tf`; OIDC ARN from a data source |
| CI: `init -backend-config="bucket="` → `The value cannot be empty` | `TF_STATE_BUCKET` was set from a file name that no longer existed → empty secret | Check the length first (`${#VAL}`), set again, `gh run rerun` |

## Left in AWS (kept on purpose, ~$0)

| Resource | Why kept |
|---|---|
| VPC + subnet | Free |
| ECR `hello-web`, role `ec2-hello` | Existed before Day 12 |
| Role `gha-tf-plan` | The workflow runs on every PR; without the role every PR would fail |
| State bucket | Holds the state (versioned) |

## What I learned

1. The **state** is Terraform's memory; the **backend** only says where it is kept. In S3 it is shared, versioned and locked.
2. `init -migrate-state` copies existing state to a new backend; partial config keeps the bucket name out of Git.
3. A module is a function: variables in, resources, outputs out. `moved` makes a refactor free (0 destroy).
4. Data sources read what already exists (AZs, the OIDC provider) instead of hard-coding it.
5. `import` blocks adopt existing resources; generated config is only a draft.
6. `fmt` / `validate` / `tflint` check different things; CI `plan` on a fresh runner proves the shared state works.
