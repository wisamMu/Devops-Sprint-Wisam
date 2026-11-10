# Day 1 — Environment Setup (Before Day 1)

**Date:** 2026-11-03
**Goal:** Prepare a free, secure workstation and AWS account for the DevOps Essentials Sprint.
**Cost:** $0 — nothing billable was created in AWS.

---

## What I built

| Area | Result |
|---|---|
| Local Linux | Ubuntu 24.04.5 LTS running in WSL 2 on Windows 11 |
| Tools | Git, AWS CLI v2, Terraform, ShellCheck, GitHub CLI, Docker (via Docker Desktop) |
| AWS account | Free plan, root user protected by MFA |
| Daily AWS identity | IAM user `wisam-admin` (AdministratorAccess + MFA) |
| CLI access | `aws login` — temporary credentials, **no access keys** |
| Cost guard | AWS Budget alert at $10 |
| Source control | GitHub repo `wisamMu/Devops-Sprint-Wisam`, cloned to `~/Devops-Sprint-Wisam` |

### Installed versions

| Tool | Version |
|---|---|
| Ubuntu (WSL 2) | 24.04.5 LTS |
| Git | 2.43.0 |
| AWS CLI | 2.39.3 |
| Terraform | 1.17.1 |
| ShellCheck | 0.9.0 |
| GitHub CLI | 2.45.0 |
| Docker | Docker Desktop on Windows, WSL integration enabled for Ubuntu-24.04 |

---

## Steps

### Step 1 — Install Ubuntu in WSL 2

Run in **PowerShell**:

```bash
wsl --install -d Ubuntu-24.04
```

- `wsl --install` installs the WSL components and a Linux distribution.
- `-d Ubuntu-24.04` picks Ubuntu 24.04 LTS (supported for 5 years).
- On first start, Ubuntu asks for a Linux username and password. They are separate from the Windows login; the password is what `sudo` asks for.

**Why:** Servers, containers and CI runners all run Linux. Working inside Ubuntu means commands, permissions and scripts behave the same locally as on EC2.

**Tip:** Keep project files in the Linux home folder (`~/`), not under `/mnt/c/`. Windows paths are slower from WSL and break Linux file permissions.

### Step 2 — Connect Docker Desktop to Ubuntu

1. Start Docker Desktop and wait for **Engine running**.
2. Docker Desktop → **Settings → Resources → WSL integration** → tick **Enable integration with my default WSL distro** and switch on **Ubuntu-24.04** → **Apply & restart**.
3. Make Ubuntu the default WSL distro (it was `docker-desktop`, Docker's internal distro), then restart WSL. In **PowerShell**:

```bash
wsl --set-default Ubuntu-24.04
wsl --shutdown
```

4. Reopen Ubuntu.

**Why:** Docker Desktop runs the Docker engine on Windows. This setting exposes the `docker` command inside Ubuntu, so Docker is not installed twice. Docker Desktop must be running for `docker` to work in Ubuntu.

### Step 3 — Install the tools inside Ubuntu

Base packages:

```bash
sudo apt update && sudo apt install -y git unzip curl gnupg software-properties-common shellcheck gh
```

| Part | Meaning |
|---|---|
| `sudo` | Run as root (needed to install software) |
| `apt update` | Refresh the list of available packages |
| `&&` | Run the next command only if the previous one succeeded |
| `apt install -y` | Install packages, answering "yes" automatically |

| Package | Used for |
|---|---|
| `git` | Version control inside Linux |
| `unzip` | Extract the AWS CLI installer |
| `curl` | Download files and test HTTP endpoints |
| `gnupg` | Verify package signatures (Terraform repo) |
| `software-properties-common` | Helpers for adding package repositories |
| `shellcheck` | Lint Bash scripts (Day 2) |
| `gh` | GitHub CLI — login, create repos, open PRs |

AWS CLI v2 (installed from Amazon's official zip, because `apt` does not ship v2):

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip && unzip -q awscliv2.zip && sudo ./aws/install && rm -rf aws awscliv2.zip
```

1. `curl ... -o awscliv2.zip` downloads the installer.
2. `unzip -q` extracts it into `aws/`.
3. `sudo ./aws/install` installs it to `/usr/local/bin/aws`.
4. `rm -rf` deletes the installer files.

Terraform (from HashiCorp's signed apt repository):

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg && echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list && sudo apt update && sudo apt install -y terraform
```

1. Download HashiCorp's public signing key and save it to the system keyring.
2. Add HashiCorp's repository; `signed-by=` makes apt trust only packages signed by that key.
3. `$(lsb_release -cs)` inserts the Ubuntu codename (`noble`) so the right build is used.
4. `sudo tee` writes the file as root (a plain `>` redirect would not run as root).
5. Refresh the package list and install Terraform.

### Step 4 — Secure the root user

AWS Console (as root) → account menu → **Security credentials** → **Assign MFA device** → authenticator app.

**Why:** Root can do anything, including closing the account, and no policy can restrict it. MFA protects it; after today it is used only for account and billing tasks.

### Step 5 — Create the daily IAM user

**IAM** → **Users** → **Create user**:

- User name: `wisam-admin`
- Console access: **I want to create an IAM user**, with a custom password
- Permissions: **Attach policies directly** → `AdministratorAccess`
- Saved the account's console sign-in URL

**Decision — IAM, not IAM Identity Center:** Enabling IAM Identity Center requires AWS Organizations. The console warned that creating an organization **upgrades the account from the Free plan to pay-as-you-go and makes the free credits expire immediately**, and the default setup also creates a billed customer-managed KMS key. I cancelled that page and used a plain IAM user, which is free and allowed by the sprint plan ("or an IAM user with MFA").

### Step 6 — Add MFA to the IAM user

IAM → Users → `wisam-admin` → **Security credentials** → **Assign MFA device** → authenticator app.

From now on I sign in daily as `wisam-admin` through the account sign-in URL, not as root.

### Step 7 — Budget alert

**Billing and Cost Management → Budgets → Create budget → Monthly cost budget → $10** with an email alert.

**Why:** The Free plan cannot bill me, but it can use up my free credits, and the account closes when they run out. The alert warns me early. Budgets warn; they do not stop resources — daily teardown does.

### Step 8 — Log the CLI in without access keys

```bash
aws login
```

- First run asked for a region → pressed **Enter** for `us-east-1` (saved in `~/.aws/config`).
- Signed in as `wisam-admin` in the browser and approved.

**Why:** `aws login` gives the CLI **temporary** credentials from my console sign-in. No long-lived access keys exist on the machine, so there is nothing to leak. When the session expires, run `aws login` again.

Check who I am:

```bash
aws sts get-caller-identity
```

Result: `arn:aws:iam::<account-id>:user/wisam-admin` ✅

### Step 9 — Set up Git and GitHub

```bash
git config --global user.name "Wisam Musleh"
git config --global user.email "<my-github-email>"
gh auth login        # GitHub.com → HTTPS → Yes → Login with a web browser
gh auth status
```

- In WSL the browser may not open; in that case open https://github.com/login/device and paste the one-time code.
- Created the repo `wisamMu/Devops-Sprint-Wisam` and cloned it:

```bash
cd ~ && gh repo clone wisamMu/Devops-Sprint-Wisam
```

### Step 10 — Verify

```bash
aws sts get-caller-identity && docker run hello-world && terraform -version
```

| Check | Proves | Result |
|---|---|---|
| `aws sts get-caller-identity` | CLI installed and logged in | ✅ `user/wisam-admin` |
| `docker run hello-world` | Docker works from Ubuntu | ✅ "Hello from Docker!" |
| `terraform -version` | Terraform installed | ✅ v1.17.1 |

---

## What broke and how I fixed it

| Problem | Cause | Fix |
|---|---|---|
| IAM Identity Center page warned about pay-as-you-go | Identity Center needs AWS Organizations, which upgrades the Free plan | Cancelled; used an IAM user with MFA instead |
| `aws login` asked "No AWS region has been configured" | First-time CLI setup | Pressed Enter to accept `us-east-1` |
| `gh: command not found` | GitHub CLI wasn't installed | `sudo apt install -y gh` |
| `docker` not found inside Ubuntu | Docker Desktop wasn't running, WSL integration was off, and the default WSL distro was `docker-desktop` | Started Docker Desktop, enabled integration for Ubuntu-24.04, ran `wsl --set-default Ubuntu-24.04` and `wsl --shutdown` |

---

## Status

✅ All setup checks pass. Ready for Day 1 — Linux essentials.
