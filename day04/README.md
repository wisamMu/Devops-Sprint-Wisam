[⬅ Back to index](../SPRINT.md)

# Day 4 — Git and GitHub

**Goal:** understand how Git stores history, how branches, merges and rebases work, how to collaborate through GitHub pull requests, and how to undo mistakes safely. Then use that workflow on the real sprint repo.

| Part | Content |
|---|---|
| 📖 Cheat sheet | The commands at a glance |
| Sections 1–8 | Concepts: headlines with a short explanation each |
| 🧪 Lab (required) | `main` and `git-lab` protected on GitHub; Days 1–3 through feature branches and PRs into `git-lab`, with self-review and a deliberate conflict; Day 4 through a PR into `main` |
| 🎯 Optional practice | 20 small tasks in throwaway repos, one for every topic |
| Lessons | What to remember |

**Sources this day covers:** Pro Git chapters 1–3, Learn Git Branching (Main → Introduction Sequence and Ramping Up), and the GitHub Skills courses *Introduction to GitHub*, *Introduction to Git*, *Review pull requests* and *Resolve merge conflicts*.

---

## 📖 Git cheat sheet

| Goal | Command |
|---|---|
| First-time setup | `git config --global user.name "…"`, `git config --global user.email "…"` |
| Help | `git help <cmd>` (full manual), `git <cmd> -h` (short usage) |
| Where am I / what changed? | `git status`, `git status -s`, `git diff`, `git diff --staged` |
| Stage / commit | `git add <file>`, `git commit -m "type: message"` |
| Stop tracking / rename | `git rm --cached <file>`, `git mv <old> <new>` |
| History | `git log --oneline --graph --all`, `git log --stat`, `git log -p` |
| Search history | `git log --author=…`, `--since=…`, `--grep=…`, `-S "text"`, `-- <path>` |
| New branch / switch | `git switch -c <name>`, `git switch <name>` |
| Manage branches | `git branch -vv`, `--merged`, `--no-merged`, `-m <old> <new>`, `-d` / `-D` |
| Move a branch | `git branch -f <branch> <commit>` |
| Relative refs | `HEAD^` (parent), `HEAD~3` (3 back), `HEAD^2` (2nd parent of a merge) |
| Merge / rebase | `git merge <branch>`, `git rebase main`, `git rebase --onto <new> <old> <branch>` |
| Conflict: take one side per file | `git checkout --ours <file>`, `git checkout --theirs <file>`, then `git add` |
| Conflict: one side wins everywhere | `git merge -X ours <branch>`, `git merge -X theirs <branch>` |
| Conflict: list / cancel | `git diff --name-only --diff-filter=U`, `git merge --abort` |
| Remotes | `git remote -v`, `git remote add/show/rename/remove` |
| Sync with GitHub | `git fetch --prune`, `git pull --rebase`, `git push -u origin <branch>` |
| Delete a remote branch | `git push origin --delete <branch>` |
| Tags | `git tag -a v1.0 -m "…"`, `git push origin v1.0`, `git push origin --tags` |
| Pull request | `gh pr create`, `gh pr diff`, `gh pr merge --squash --delete-branch` |
| Undo, not committed | `git restore <file>`, `git restore --staged <file>` |
| Undo, committed not pushed | `git commit --amend`, `git reset --soft HEAD~1` |
| Undo, pushed | `git revert <commit>` |
| Lost something | `git reflog` |
| Shelve work | `git stash`, `git stash pop` |

| Situation | Use |
|---|---|
| Not committed | `restore` |
| Committed, not pushed | `amend` / `reset` |
| Committed and pushed | `revert` |
| Lost a commit | `reflog` |

---

## Section 1 — What Git is

| Headline | Explanation |
|---|---|
| **Version control** | A system that records every change to files: who, when, why. You can go back to any version, and many people can work on the same files safely. |
| **Local → centralized → distributed** | Local: copies on one disk. Centralized (SVN): one server holds history. **Distributed (Git)**: every clone has the **full history**, so most work is offline. GitHub is just the shared copy. |
| **Git vs GitHub** | **Git** is the program that tracks history on your machine. **GitHub** is a website that hosts repos and adds PRs, reviews and Actions. Alternatives: GitLab, Azure DevOps. |
| **Snapshots** | Each commit stores a picture of **all files** at that moment, not a list of differences. Unchanged files are pointers to the copy already stored. |
| **Integrity** | Everything is identified by a hash of its content, so Git notices any corruption or tampering. |
| **Commit** | A saved snapshot plus author, date, message and **parent** (the previous commit). Commits link backwards into a history chain. |
| **Good commit** | One logical change, with a message explaining **why**: "Add Day 3 networking notes", not "stuff". |
| **The three areas** | **Working tree**: your files. **Staging area (index)**: a draft of the next commit. **Repository (`.git`)**: saved history. |
| **Why staging** | You choose exactly which changes go into a commit, so one commit holds one clean change. |
| **File states** | Untracked → Staged → Unmodified → Modified → Staged… Ignored files (in `.gitignore`) are invisible to Git. |
| **`git status`** | Your dashboard: shows which area every change is in. |
| **`.git` folder** | **Is** the repository. Delete it and the history is gone. |

```text
Working tree ──git add──► Staging area ──git commit──► Repository (.git)
```

### 1.1 First-time setup and getting help
| Headline | Explanation |
|---|---|
| **`git config`** | Stores settings. Your **name and email** go into every commit you make, so set them first. |
| **Three levels** | `--system` (every user, `/etc/gitconfig`) → `--global` (you, `~/.gitconfig`) → `--local` (one repo, `.git/config`). **The most specific wins**: local beats global. |
| **Useful settings** | `user.name`, `user.email`, `core.editor` (e.g. `nano`), `init.defaultBranch main`, `merge.conflictstyle zdiff3` |
| **See where a value comes from** | `git config --list --show-origin`, or `git config --show-origin user.email` |
| **Per-repo identity** | `git config user.email work@company.com` inside the work repo: a different email there only |
| **Help** | `git help <command>` opens the full manual; `git <command> -h` prints a short usage summary. |

### 1.2 Recording changes: the extras
| Headline | Explanation |
|---|---|
| **`git status -s`** | Short format, two columns: **left = staging area, right = working tree**. `??` untracked, `A ` added, ` M` modified not staged, `M ` modified and staged, `R ` renamed. |
| **`.gitignore` patterns** | `*.log` every .log file · `!keep.log` exception (do track it) · `build/` a whole folder · `**/tmp.py` that name in any folder · `/todo.txt` only at the root. |
| **`git check-ignore -v <file>`** | Shows **which line** of `.gitignore` ignores a file. |
| **`git rm <file>`** | Delete the file and stage the deletion. |
| **`git rm --cached <file>`** | Stop **tracking** a file but **keep it on disk**. Use it when a log or `.env` was committed by mistake (then add it to `.gitignore`). |
| **`git mv <old> <new>`** | Rename or move a file and stage it in one step. History follows it with `git log --follow`. |

---

## Section 2 — Inside Git

| Headline | Explanation |
|---|---|
| **Objects** | Git stores three kinds: **blob** (a file's content), **tree** (a folder), **commit** (a tree + metadata + parent). Annotated tags are a fourth kind. |
| **Hash (SHA)** | Each object's ID, like `def081f`, is a fingerprint of its content. If the content changes, the ID changes. |
| **Ref** | A readable name pointing to a commit, such as `main` or `v1.0`. |
| **Branch** | Just a **movable pointer** to a commit. New commits move it forward. Creating one is instant. |
| **HEAD** | "Where you are now". It usually points to the current branch. |
| **Detached HEAD** | HEAD points at a commit, not a branch. New commits there get lost unless you create a branch. |

```text
                 HEAD → main
                          ▼
A ◄── B ◄── C ◄── D (def081f)
```

### 2.1 Relative refs: moving around without hashes
| Headline | Explanation |
|---|---|
| **`^` (caret)** | "The parent of". `HEAD^` = one commit back, `HEAD^^` = two back. |
| **`~N` (tilde)** | "N commits back along the first parent". `HEAD~3` = `HEAD^^^`. |
| **`^2`** | On a **merge commit** only: the **second parent** (the branch that was merged in). `HEAD^1` is the first parent (the branch you were on). |
| **Works anywhere** | `main~2`, `feature^`, `v1.0~1` — any ref plus `^` or `~`. |
| **`git branch -f <branch> <commit>`** | **Force-move** a branch pointer, e.g. `git branch -f main HEAD~3`. Only on your own, unpushed branches. |

```text
            HEAD^2 (side)
              │
A ◄── B ◄── C ◄──── M  ← HEAD (merge commit)
      │     │
   HEAD~2  HEAD^ = HEAD^1 = HEAD~1
```

---

## Section 3 — Branches and merging

| Headline | Explanation |
|---|---|
| **Why branch** | Work in isolation; `main` stays stable until the work is ready. |
| **Merge** | Brings another branch's commits into the current branch. |
| **Fast-forward** | `main` didn't move, so Git just slides the pointer forward. No new commit is made. |
| **3-way merge** | Both branches moved, so Git combines them from their common ancestor and creates a **merge commit**. |
| **Conflict** | Both sides changed the **same lines**. Git marks the file (`<<<<<<<`, `=======`, `>>>>>>>`), you choose the result, then `add` and `commit`. |
| **Naming** | `feature/vpc-lab`, `fix/healthcheck-exit`, `docs/day04-git`, `hotfix/...` |

```text
Fast-forward:  main ─A─B            →  main ─A─B─C─D
                     └─C─D (feature)

3-way:         main ─A─B─E          →  main ─A─B─E───M   (M = merge commit)
                     └─C─D (feature)         └─C─D─┘
```

## Section 3.1 — Resolving merge conflicts (ours, theirs, -X)

### The vocabulary
| Term | Meaning during a **merge** (`git merge feature` while on `main`) |
|---|---|
| **Ours** | The branch you are **on** — `main` (HEAD) |
| **Theirs** | The branch you are **merging in** — `feature` |
| **Base** | The common ancestor both sides started from |
| **Conflict markers** | `<<<<<<< HEAD` (ours) … `=======` … `>>>>>>> feature` (theirs) written into the file |
| **Conflicting hunk** | A block of lines **both** sides changed. Only these stop the merge; everything else merges automatically. |

⚠️ **During a rebase, ours and theirs are swapped.** Rebase replays *your* commits on top of `main`, so **ours = `main`** (the base being built on) and **theirs = your commit** being replayed.

| Operation | `--ours` / `-X ours` = | `--theirs` / `-X theirs` = |
|---|---|---|
| `git merge feature` (on main) | `main` | `feature` |
| `git merge origin/main` (on your branch) | your branch | `main` from GitHub |
| `git rebase main` (on feature) | `main` | **your** feature commit |
| `git pull` (merge) | your local branch | the remote |
| `git pull --rebase` | the remote | your local commits |

### Three ways to resolve
| Level | How | When |
|---|---|---|
| **Manual (line by line)** | Edit the file, remove markers, keep the right lines | Both sides contain something you need — the normal case |
| **File by file** | `git checkout --ours <file>` or `--theirs <file>` | One side is clearly right **for that file** (a lock file, generated file, a config you own) |
| **Globally (whole merge)** | `git merge -X ours …` or `-X theirs …` | You know one side should win **every** conflict; Git doesn't even stop |

### File-by-file: `--ours` / `--theirs`
```bash
git merge feature/configs               # → CONFLICT in app.conf and site.conf

git checkout --ours   app.conf          # keep main's version of this file
git checkout --theirs site.conf         # keep feature's version of this file
# same thing, newer syntax:
# git restore --ours app.conf
# git restore --theirs site.conf

git checkout --theirs -- docs/          # works for a whole folder too

git add app.conf site.conf              # mark them resolved
git commit --no-edit                    # finish the merge
```
| Part | Meaning |
|---|---|
| `checkout --ours <file>` | Replace the conflicted file with **our** side's version, whole file |
| `checkout --theirs <file>` | Replace it with **their** side's version |
| `--` | "Everything after this is a path", avoids confusion with branch names |
| `git add` | Tells Git "this file is resolved". **Required** — choosing a side alone isn't enough. |

> Careful: `--ours`/`--theirs` take the **whole file** from one side, including that side's non-conflicting changes to the same file.

### Globally: `-X ours` / `-X theirs` (strategy options)
```bash
git merge -X theirs feature/configs     # every conflicting hunk → feature wins
git merge -X ours   feature/configs     # every conflicting hunk → main wins
git pull  -X theirs                     # same idea while pulling
git rebase -X theirs main               # remember: here "theirs" = YOUR commits
```
| Part | Meaning |
|---|---|
| `-X` | Passes an **option** to the merge strategy |
| `-X ours` / `-X theirs` | Resolve **only conflicting hunks** automatically in favour of one side. Non-conflicting changes from **both** sides are still merged in. |

### `-X ours` vs `-s ours` — don't mix them up
| | `-X ours` (option) | `-s ours` (strategy) |
|---|---|---|
| Conflicting hunks | Our side wins | — |
| Their **non-conflicting** changes | ✅ Kept | ❌ **Thrown away — the whole branch is ignored** |
| Result | A real merge, conflicts auto-solved | A merge commit that records the branch as merged but contains **none** of its changes |
| Use | "Merge, prefer us on clashes" | Rare: mark an obsolete branch as merged |
| `-s theirs` | — | Doesn't exist |

### Step-by-step resolution workflow
```bash
# 1. Start the merge and see it stop
git merge feature/configs

# 2. List the conflicted files
git status                                  # "both modified: …"
git diff --name-only --diff-filter=U        # just the names (U = unmerged)

# 3. Understand each conflict
git diff                                    # conflicts with markers
git show :1:app.conf                        # BASE version
git show :2:app.conf                        # OURS version
git show :3:app.conf                        # THEIRS version
git log --oneline --left-right main...feature/configs   # who changed what

# 4. Decide per file: edit by hand, OR take one side
git checkout --ours   app.conf
git checkout --theirs site.conf

# 5. Mark each file resolved
git add app.conf site.conf

# 6. Make sure no markers are left
git diff --cached --check                   # warns on leftover conflict markers
grep -rnE '^(<<<<<<<|=======|>>>>>>>)' . --exclude-dir=.git || echo "no markers"

# 7. Test (run the script / build / tests)

# 8. Finish
git commit --no-edit                        # or: git merge --continue (opens the editor)
```
| Step | Command | Meaning |
|---|---|---|
| 2 | `--diff-filter=U` | Only **U**nmerged (conflicted) files |
| 3 | `:1:` `:2:` `:3:` | The three versions Git keeps during a conflict: base, ours, theirs |
| 3 | `main...feature` with `--left-right` | Commits unique to each side, marked `<` and `>` |
| 6 | `diff --check` | Catches leftover `<<<<<<<` markers before you commit them |
| 8 | `merge --continue` | Same as committing, but only works while a merge is in progress. It takes **no other options** (`--no-edit` is an error); use `git commit --no-edit` to skip the editor. |

### Escape hatches
| Command | Meaning |
|---|---|
| `git merge --abort` | Cancel the merge, go back to before it started |
| `git rebase --abort` | Cancel the rebase |
| `git checkout --merge <file>` | Re-create the conflict markers in a file you resolved wrongly |
| `git reset --hard HEAD~1` | Undo a merge **commit** that isn't pushed yet (pushed → `git revert -m 1 <merge>`) |

### Make conflicts easier to read (one-time)
```bash
git config --global merge.conflictstyle zdiff3
```
Adds a third block — `||||||| base` — showing what the lines looked like **before** either side changed them, so you can see *what each side intended*.

## Section 3.2 — Branch management and workflows

### Managing branches
| Headline | Explanation |
|---|---|
| **`git branch -v` / `-vv`** | List branches with their last commit; `-vv` adds the tracked remote branch and "ahead/behind". |
| **`--merged` / `--no-merged`** | Branches already merged into the current one (safe to delete) / not yet merged (would lose work). |
| **`git branch -m <old> <new>`** | Rename a branch. |
| **`-d` vs `-D`** | `-d` deletes only if merged (safe); `-D` forces it (loses unmerged commits). |
| **Delete on GitHub** | `git push origin --delete <branch>`. Others then run `git fetch --prune` to drop the stale `origin/<branch>`. |
| **Upstream** | `git push -u origin <branch>` sets it on the first push; `git branch --set-upstream-to=origin/<branch>` sets it later. |

### Branching workflows
| Headline | Explanation |
|---|---|
| **Long-running branches** | Branches that live forever at different stability levels: `main` (released) and often `develop`/`development` (integration). Work flows *up* as it gets stable. |
| **Topic (feature) branches** | Short-lived, one per task (`feature/…`, `fix/…`, `docs/…`). Merged by PR, then deleted. |
| **Hotfix branches** | Cut from the released branch to fix production fast (`hotfix/…`), merged back to every long-running branch. |
| **GitHub flow** | Just `main` + short topic branches + PRs. Simple; what this sprint uses. |
| **Git flow** | `main` + `develop` + feature/release/hotfix branches. More ceremony, for scheduled releases. |
| **Your work repo** | A Git-flow style: `development` as the integration branch, `hotfix/*` for urgent fixes, PRs into `development`. |

```text
GitHub flow (this sprint):           Git flow (long-running branches):
main ──●────────●────────●──          main     ──●────────────●──── (releases, tags)
        \      /  \     /                         \          /
         ●──●─●    ●──●●              develop ─●───●──●──●──●──────
        docs/day01  docs/day02                     \      /
                                      feature/x     ●──●─●
```

---

## Section 4 — Rebase vs merge

| Headline | Explanation |
|---|---|
| **Rebase** | Replays your commits **on top of** the latest `main`, giving a straight, linear history. |
| **Merge vs rebase** | Merge **keeps** the true history; rebase **rewrites** it to look cleaner. |
| **New hashes** | Rebased commits are new commits with new IDs. |
| **Golden rule** | **Never rebase commits others already pulled.** Rebase only your own local work. A pushed PR branch? Merge `main` into it instead. |
| **Squash** | Combine several small commits into one, common when merging a PR. |
| **`rebase --onto`** | Move only **part** of a branch. `git rebase --onto main server client` takes the commits on `client` that aren't on `server` and replays them on `main`. |

```text
Before:  main ─A─B                      git rebase --onto main server client
              └─S1─S2  (server)
                    └─C1─C2 (client)    After:  main ─A─B─C1'─C2' (client)
                                                     └─S1─S2 (server, unchanged)
```

---

## Section 5 — Remotes

| Headline | Explanation |
|---|---|
| **Remote** | Another copy of the repo, usually on GitHub. The default name is **`origin`**. |
| **Clone** | Download a full copy, with its whole history. |
| **Fetch** | Download new commits **without changing** your files. |
| **Pull** | Fetch + merge (or rebase) into your current branch. |
| **Push** | Upload your commits. Rejected if the remote has commits you don't have, so pull first. |
| **Tracking branch** | Local `main` tracks `origin/main`, so `git status` can say "ahead 1" or "behind 2". |
| **Remote-tracking branch** | `origin/main` is your **read-only bookmark** of where `main` was on GitHub at your last fetch. |
| **Force push** | Overwrites remote history. Dangerous on shared branches; use `--force-with-lease` if you must. |
| **Managing remotes** | `git remote -v` (list), `add <name> <url>`, `show <name>` (branches and tracking), `rename <old> <new>`, `remove <name>`. |

---

## Section 6 — GitHub collaboration

| Headline | Explanation |
|---|---|
| **Pull request (PR)** | A request to merge one branch into another, with discussion, review and CI checks. |
| **Code review** | Teammates read the diff and approve or request changes **before** it reaches `main`. |
| **Self-review** | Read your own diff before asking anyone: right files only, no secrets or debug lines, clear title. You can **comment** on your own PR but not **approve** it. |
| **Branch protection** | Rules on a branch enforced **by GitHub's server**: no direct pushes, PR and approvals required, CI must pass, rules apply to admins too. Always free on public repos; on private repos it depends on the plan — check with `gh api repos/<owner>/<repo>/branches/main/protection` (404 "Branch not protected" = available; 403 "Upgrade" = not). It worked on this sprint repo. |
| **Local guard (pre-push hook)** | A script Git runs before every push that can refuse pushes to `main`. The fallback when server-side protection isn't available: free, but only on machines where it's installed, and `--no-verify` skips it (optional Task 20). |
| **CODEOWNERS** | Auto-assigns reviewers by path, for example `infra/` → the DevOps team. |
| **Merge strategies** | Merge commit, **squash and merge**, or rebase and merge. |
| **Commit messages** | Short imperative summary ("Add VPC lab"). **Conventional Commits** add a type: `feat:`, `fix:`, `docs:`, `chore:`. |
| **Fork** | Your own copy of someone else's repo, used for open-source contributions. |

---

## Section 7 — Undoing things, and safety

| Headline | Explanation |
|---|---|
| **`restore`** | Discard **uncommitted** changes, or unstage a file (`--staged`). |
| **`commit --amend`** | Fix the **last** commit. Only before pushing. |
| **`reset`** | Move the branch back. `--soft` keeps changes staged, `--mixed` keeps them unstaged, **`--hard` deletes them**. |
| **`revert`** | A **new commit that undoes** an old one. The safe undo for pushed work. |
| **`reflog`** | A history of where HEAD has been; it recovers "lost" commits. |
| **`stash`** | Temporarily shelve uncommitted work. |
| **`.gitignore`** | Files Git must never track: logs, build output, `.env`. |
| **Secrets** | Never commit them. They stay in history even after deletion. If one leaks, **rotate it**. |

---

## Section 8 — History, tags and aliases

### Viewing and searching history
| Option | Shows |
|---|---|
| `git log --stat` | Which files each commit changed, and how much |
| `git log -p` | The full diff of each commit |
| `git log --oneline --graph --all` | One line per commit, with branches drawn |
| `--author="name"` | Commits by one person |
| `--since="2 weeks ago"`, `--until=…` | A time window |
| `--grep="vpc"` | Commits whose **message** contains the word |
| `-S "text"` | Commits that **added or removed** that text in the code (the "pickaxe") |
| `-- <path>` | Only commits that touched that file or folder |
| `--follow -- <file>` | Keep following a file through renames |
| `--pretty=format:'%h %an %ar %s'` | Your own format: hash, author, relative date, subject |

### Tags
| Headline | Explanation |
|---|---|
| **Tag** | A permanent, **fixed** name on one commit — a release marker like `v1.0`. Unlike a branch, it never moves. |
| **Lightweight tag** | `git tag v0.1` — just a pointer, no extra info. Fine for private bookmarks. |
| **Annotated tag** | `git tag -a v1.0 -m "First release"` — a real object with tagger, date and message. **Use these for releases.** |
| **Tag an old commit** | `git tag -a v0.9 -m "…" <commit>` |
| **Tags aren't pushed automatically** | `git push origin v1.0` (one) or `git push origin --tags` (all). |
| **Delete** | `git tag -d v0.1` locally, `git push origin --delete v0.1` on GitHub. |
| **Check out a tag** | `git switch --detach v1.0` → detached HEAD; create a branch if you want to change anything. |
| **Why DevOps cares** | Releases, changelogs and Docker image versions (Week 2) are tied to tags. |

### Aliases
| Headline | Explanation |
|---|---|
| **Alias** | Your own short name for a Git command, stored in `~/.gitconfig`. |
| **Examples** | `git config --global alias.st "status -s"` → `git st`. `alias.lg "log --oneline --graph --decorate --all"` → `git lg`. |
| **List them** | `git config --global --get-regexp '^alias\.'` |

---

# 🧪 Lab — Git workflow on the real sprint repo (required)

**The task:** push Days 1–3 to the repo **using feature branches**. Open a **PR**, **review your own diff** before merging, and **resolve a deliberate merge conflict**. **Protect `main`** so nothing is pushed to it directly. Then ship Day 4 the same way.

**Time:** about 1.5 hours. **Where:** WSL, in `~/Devops-Sprint-Wisam`. **Cost:** free.

### How the lab is set up
| Branch | Role |
|---|---|
| `main` | Days 1–3 were pushed here directly, before this workflow. We **don't rewrite its history** (that would need a force push). Day 4 arrives here through a PR. |
| `git-lab` | The practice branch (its own history: README, `hello.sh`, the title-conflict merge…). Days 1–3 are delivered **into it** through feature branches and PRs, plus a `SPRINT.md` index. |

| Step | What you do | Covers |
|---|---|---|
| 0 | Check `main`'s protection status | Section 6 |
| 1 | **Protect `git-lab` and `main` on GitHub**: PR required, rules apply to admins | Section 6 |
| 2 | Prove a direct push is **rejected by GitHub** | Section 6 |
| 3 | **Day 1**: feature branch from `git-lab`, PR, **self-review**, squash-merge | Sections 3, 6 |
| 4 | **Day 3** merged first; **Day 2** branched from the commit *before* Day 3 | Sections 2.1, 3 |
| 5 | Day 2 **conflicts** with Day 3 → resolve, review again, merge | Sections 3.1, 5 |
| 6 | **Day 4**: feature branch from `main`, PR into `main` | All |
| 7 | Verify: history, merged PRs, no leftover branches | Sections 3.2, 8 |

```text
git-lab ──●───────── #1 ────────── #2 ─────────────── #3 ──
       (practice)   Day 1    \     Day 3               ↑  Day 2
                              \                        │
                               └── Day 2 branch ── merge origin/git-lab
                                   (from Day 1)    (conflict fixed here)

main    ──● Day 3 notes ─────────────────────────────────── #4 Day 4
```

---

## Step 0 — Is `main` protected?
```bash
cd ~/Devops-Sprint-Wisam
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
gh api "repos/$REPO/branches/main/protection"
```
| Command | Meaning |
|---|---|
| `gh repo view --json nameWithOwner -q .nameWithOwner` | Prints `<you>/Devops-Sprint-Wisam` for this folder |
| `REPO=$( … )` | Saves it, so no names are typed by hand |
| `gh api …/branches/main/protection` | Reads `main`'s protection rules |

**Result:** `"message": "Branch not protected"` (HTTP 404). GitHub answered normally — `main` just had **no rules yet** — so protection is available for this repo.

| Possible answer | Meaning |
|---|---|
| 404 `Branch not protected` | Available, nothing set yet (our case) |
| 403 `Upgrade to GitHub Pro or make this repository public` | Not available on this plan → fall back to a local pre-push hook (optional Task 20) |
| JSON with rules | Already protected |

## Step 1 — Protect `git-lab` and `main` on GitHub
```bash
gh api user -q '.plan.name'

for BRANCH in git-lab main; do
  echo "== protecting $BRANCH"
  gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" --input - <<'EOF' > /dev/null
{"required_status_checks": null,
 "enforce_admins": true,
 "required_pull_request_reviews": {"required_approving_review_count": 0},
 "restrictions": null}
EOF
  gh api "repos/$REPO/branches/$BRANCH/protection" \
    -q '{pr_required: (.required_pull_request_reviews != null), admins_included: .enforce_admins.enabled}'
done
```
| Command | Meaning |
|---|---|
| `gh api user -q '.plan.name'` | Your GitHub plan (`free` / `pro`) |
| `for BRANCH in git-lab main; do … done` | Run the same commands for each branch |
| `gh api -X PUT …/protection` | **Create** the protection rules (PUT = set) |
| `--input - <<'EOF' … EOF` | Send the JSON rules as the request body |
| `> /dev/null` | Hide the long JSON reply; errors still show |
| `required_approving_review_count: 0` | **Every change must come through a PR**; zero approvals because you can't approve your own PR |
| `"enforce_admins": true` | The rules apply to **you** too, as the owner |
| `"required_status_checks": null` | No CI checks required yet (Day 8) |
| `"restrictions": null` | No per-user push list (organizations only) |
| `gh api …/protection -q '{…}'` | Read the rules back: PR required? admins included? |

**Expected:**
```text
== protecting git-lab
{"admins_included":true,"pr_required":true}
== protecting main
{"admins_included":true,"pr_required":true}
```
Also visible in the browser: **Settings → Branches → Branch protection rules**.

## Step 2 — Prove a direct push is rejected
```bash
git switch git-lab
git commit --allow-empty -m "test: direct push"
git push
git reset --hard origin/git-lab

git switch main
git commit --allow-empty -m "test: direct push"
git push
git reset --hard origin/main
git log --oneline -1
```
| Command | Meaning |
|---|---|
| `git switch git-lab` | No local `git-lab` yet → Git creates one tracking `origin/git-lab` |
| `git commit --allow-empty` | A commit with no file changes: a harmless test |
| `git push` | Try to push **directly** to the protected branch |
| `git reset --hard origin/<branch>` | Throw the test commit away (safe: it was never pushed) |

**Expected, for each push:**
```text
remote: error: GH006: Protected branch update failed for refs/heads/git-lab.
remote: - Changes must be made through a pull request.
 ! [remote rejected] git-lab -> git-lab (protected branch hook declined)
error: failed to push some refs to 'https://github.com/…'
```
| Part | Meaning |
|---|---|
| `GH006: Protected branch update failed` | **GitHub's server** refused it — from any computer, and `--no-verify` can't skip it |
| `Changes must be made through a pull request` | The rule from Step 1 |
| `[remote rejected]` | The push didn't happen |

## Step 3 — Day 1 through a feature branch and PR

### 3.1 Branch, bring in Day 1, start the index
```bash
git switch git-lab && git pull
git switch -c docs/day01
git checkout origin/main -- day01
cat > SPRINT.md <<'EOF'
# DevOps Sprint — progress

| Day | Topic | Notes |
|---|---|---|
| 1 | Environment setup and Linux | [setup](day01/README.md), [Linux](day01/linux.md) |
EOF
git add SPRINT.md
git status -s
```
| Command | Meaning |
|---|---|
| `git switch git-lab && git pull` | Start from the **latest** base branch |
| `git switch -c docs/day01` | Topic branch named type/scope |
| `git checkout origin/main -- day01` | Copy `day01/` **as it is on `origin/main`** into this branch. `--` = "paths follow". Works across unrelated histories and **stages** the files. |
| `cat > SPRINT.md <<'EOF'` | Create the index with the Day 1 row (the `git-lab` README stays untouched) |
| `git add SPRINT.md` | Stage only this file |
| `git status -s` | `A  SPRINT.md`, `A  day01/README.md`, `A  day01/linux.md` (`A` left column = added and staged) |

### 3.2 Commit, push the branch, open the PR
```bash
git commit -m "docs: add Day 1 notes and sprint index"
git push -u origin docs/day01
gh pr create --base git-lab --title "docs: add Day 1 notes" \
  --body "Brings day01 (setup + Linux) into git-lab and starts SPRINT.md."
```
| Command | Meaning |
|---|---|
| `git push -u origin docs/day01` | Upload the **branch** — allowed, only `main`/`git-lab` are protected. `-u` sets tracking. |
| `gh pr create --base git-lab` | Open a PR from `docs/day01` **into `git-lab`** |

### 3.3 Review your own diff before merging
```bash
gh pr view
git diff --stat origin/git-lab...docs/day01
git diff origin/git-lab...docs/day01 | grep -nE '\b[0-9]{12}\b|AKIA[0-9A-Z]{16}|aws_secret_access_key' || echo "no secrets found"
gh pr view --web
gh pr review --comment --body "Self-review: day01 + SPRINT.md only, no secrets."
```
| Command | Meaning |
|---|---|
| `gh pr view` | Title, body, branches, state |
| `git diff --stat A...B` | Files and line counts B changed since it left A — exactly what the PR shows |
| `grep -nE '…'` | Scan for a 12-digit AWS account ID (`\b` = word boundary), an access key (`AKIA` + 16), or a secret key name |
| `\|\| echo "no secrets found"` | `grep` found nothing (exit 1) → print a clear OK |
| `gh pr view --web` | Read the **Files changed** tab; check the table renders |
| `gh pr review --comment` | Record the review (you can **comment** on your own PR, not **approve** it) |

**Self-review checklist**
| Check | Look for |
|---|---|
| Right files only | `--stat` lists only what you meant to change |
| No secrets | No account ID, keys, passwords, IPs, emails |
| Correct content | Links point to real files; tables render |
| Clean title | Conventional and imperative: `docs: …` |

### 3.4 Merge
```bash
gh pr merge --squash --delete-branch
git switch git-lab && git pull
git log --oneline -3
cat SPRINT.md
```
| Command | Meaning |
|---|---|
| `gh pr merge --squash` | GitHub merges the PR as **one commit** — the allowed way into a protected branch |
| `--delete-branch` | Delete `docs/day01` on GitHub and locally |
| `git log --oneline -3` | Top commit: `docs: add Day 1 notes (#…)` |

## Step 4 — Day 3 first, then Day 2 from *before* Day 3

### 4.1 Day 3 branch, PR, merge
```bash
git switch git-lab && git pull
git switch -c docs/day03
git checkout origin/main -- day03
echo "| 3 | Networking and VPC | [day03](day03/README.md), [userdata.sh](day03/userdata.sh) |" >> SPRINT.md
git add SPRINT.md
git status -s
git commit -m "docs: add Day 3 notes and VPC lab guide"
git push -u origin docs/day03
gh pr create --base git-lab --fill
git diff --stat origin/git-lab...docs/day03
gh pr review --comment --body "Self-review: day03 + SPRINT.md row 3."
gh pr merge --squash --delete-branch
```
| Command | Meaning |
|---|---|
| `git checkout origin/main -- day03` | Bring `day03/` (`README.md`, `userdata.sh`) in from `main`, already staged |
| `echo "| 3 | … |" >> SPRINT.md` | `>>` appends the Day 3 row **right after row 1** |
| `gh pr create --fill` | Use the commit message as the PR title and body |
| `git diff --stat …` → `gh pr review` → `gh pr merge` | Self-review, comment, squash-merge (as in Step 3) |

`SPRINT.md` on `git-lab` now has rows **1 and 3**.

### 4.2 Clean up the finished branch
```bash
git switch git-lab && git pull
git branch -D docs/day03
git push origin --delete docs/day03
git status -s
```
| Command | Meaning |
|---|---|
| `git branch -D docs/day03` | Delete the local branch. `-D` because after a **squash** merge Git thinks the branch is unmerged (its commits aren't on `git-lab`, only their squashed copy). |
| `git push origin --delete docs/day03` | Delete it on GitHub too, if `--delete-branch` didn't |
| `git status -s` | Must be clean (only `?? day04/`) before starting the next branch |

### 4.3 Day 2 branch from the commit **before** Day 3
```bash
git switch -c docs/day02 origin/git-lab~1
git checkout origin/main -- day02
echo "healthcheck.log" >> .gitignore
echo "| 2 | Bash scripting | [day02](day02/README.md), [healthcheck.sh](day02/healthcheck.sh) |" >> SPRINT.md
git add .gitignore SPRINT.md
git status -s
git commit -m "docs: add Day 2 notes and healthcheck.sh"
git push -u origin docs/day02
gh pr create --base git-lab --fill
```
| Command | Meaning |
|---|---|
| `origin/git-lab~1` | One commit before the tip of `git-lab` = the Day 1 commit, **before Day 3 arrived** (Section 2.1) |
| `git switch -c docs/day02 <start>` | Create the branch **from that commit** instead of from where you are |
| `echo "healthcheck.log" >> .gitignore` | Keep the script's log out of Git |
| `>> SPRINT.md` | Row 2 lands **right after row 1** — the same spot Day 3 used → the deliberate conflict |
| `git status -s` | `M  .gitignore`, `M  SPRINT.md`, `A  day02/README.md`, `A  day02/healthcheck.sh` |

## Step 5 — Resolve Day 2's conflict

### 5.1 See the conflict
```bash
gh pr view --json mergeable -q .mergeable
git fetch origin
git merge origin/git-lab
git diff --name-only --diff-filter=U
cat SPRINT.md
```
| Command | Meaning |
|---|---|
| `--json mergeable -q .mergeable` | → **`CONFLICTING`** (`UNKNOWN` = still computing, retry) |
| `git fetch origin` | Download the latest `git-lab` (with Day 3) without touching files |
| `git merge origin/git-lab` | Bring it **into the branch**. Merge, not rebase — the branch is already pushed (golden rule). → `CONFLICT (content): Merge conflict in SPRINT.md` |
| `--diff-filter=U` | Only unmerged files → `SPRINT.md` |

```text
| 1 | Environment setup and Linux | [setup](day01/README.md), [Linux](day01/linux.md) |
<<<<<<< HEAD
| 2 | Bash scripting | [day02](day02/README.md), [healthcheck.sh](day02/healthcheck.sh) |
=======
| 3 | Networking and VPC | [day03](day03/README.md), [userdata.sh](day03/userdata.sh) |
>>>>>>> origin/git-lab
```
| Block | Is |
|---|---|
| `HEAD` (**ours**) | The Day 2 branch |
| `origin/git-lab` (**theirs**) | `git-lab`, which already has Day 3 |

`.gitignore` and `day02/` merged **automatically** — only the lines both sides changed conflict.

### 5.2 Resolve: keep both rows, in order
```bash
git checkout --theirs SPRINT.md
sed -i '/^| 1 |/a | 2 | Bash scripting | [day02](day02/README.md), [healthcheck.sh](day02/healthcheck.sh) |' SPRINT.md
cat SPRINT.md
git add SPRINT.md
git diff --cached --check && echo "no markers left"
git commit --no-edit
git push
```
| Command | Meaning |
|---|---|
| `git checkout --theirs SPRINT.md` | Take `git-lab`'s version: rows 1 and 3, no markers |
| `sed -i '/^\| 1 \|/a …'` | **A**ppend row 2 right after the line that starts with `\| 1 \|` → order 1, 2, 3 |
| `git add SPRINT.md` | Mark it **resolved** (required) |
| `git diff --cached --check` | Warns on any leftover markers |
| `git commit --no-edit` | The merge commit, with Git's default message |
| `git push` | A normal push of the branch; the PR updates itself |

> By hand instead: `nano SPRINT.md`, delete the three marker lines, keep row 2 above row 3.

Neither `--ours` nor `--theirs` alone is right here: each would **drop one row**. That's the normal case for a conflict — combine both sides.

### 5.3 Review again and merge
```bash
gh pr view --json mergeable -q .mergeable
git diff --stat origin/git-lab...HEAD
gh pr review --comment --body "Self-review: day02, .gitignore, row 2 in order."
gh pr merge --squash --delete-branch
git switch git-lab && git pull
cat SPRINT.md
```
| Command | Meaning |
|---|---|
| `mergeable` | Now **`MERGEABLE`** |
| `git diff --stat origin/git-lab...HEAD` | Only `.gitignore` (+1), `SPRINT.md` (+1) and `day02/` — Day 3's files are already on `git-lab` |

**Final `SPRINT.md`:**
```text
| Day | Topic | Notes |
|---|---|---|
| 1 | Environment setup and Linux | [setup](day01/README.md), [Linux](day01/linux.md) |
| 2 | Bash scripting | [day02](day02/README.md), [healthcheck.sh](day02/healthcheck.sh) |
| 3 | Networking and VPC | [day03](day03/README.md), [userdata.sh](day03/userdata.sh) |
```

### 📝 Lab log — what actually happened
| PR | Branch | Into | Contents | Notes |
|---|---|---|---|---|
| #1 | `docs/day01` | `git-lab` | `day01/`, new `SPRINT.md` | Clean |
| #2 | `docs/day03` | `git-lab` | `day03/`, row 3 | Merged **before** Day 2, so no conflict yet |
| #3 | `docs/day03` (reused) | `git-lab` | `day02/`, `.gitignore`, row 2 | Day 2 was committed on the **old `docs/day03` branch** instead of a new `docs/day02`. Merging `origin/git-lab` gave the deliberate `SPRINT.md` conflict, resolved to rows 1-2-3. The PR got the title `docs/day03`, because `--fill` uses the **branch name** when a branch has several commits. |
| #4 | `docs/day04` | `main` | `day04/README.md` | Step 6 |

**Lessons from the log**
| Mistake | Avoid it next time |
|---|---|
| Reused a merged branch name for new work | After a merge: `git switch git-lab && git pull`, delete the old branch, then `git switch -c <new-name>` |
| PR title became the branch name | Pass `--title "docs: …"` explicitly, or rename it: `gh pr edit <n> --title "…"` |
| A review comment landed on the wrong PR | Name the PR: `gh pr review <number or branch> --comment …` |
| Leftovers in the working tree (a duplicate row, an old log) | Run `git status -s` before every new branch — it must be clean |

## Step 6 — Ship Day 4 to `main`
```bash
git switch main && git pull
git switch -c docs/day04
git status -s
git add day04/README.md
git commit -m "docs: add Day 4 Git and GitHub notes and lab"
git push -u origin docs/day04
gh pr create --base main --fill
git diff --stat origin/main...docs/day04
gh pr review --comment --body "Self-review: day04/README.md only, no secrets."
gh pr merge --squash --delete-branch
git switch main && git pull
git log --oneline -3
```
| Command | Meaning |
|---|---|
| `git switch -c docs/day04` | Topic branch from the latest `main` |
| `git status -s` | `?? day04/` — the notes were waiting untracked |
| `git add day04/README.md` | Stage it on the right branch |
| `gh pr create --base main` | This PR targets **`main`** |
| The rest | Same review-and-merge flow |

## Step 7 — Verify
```bash
git fetch --prune
git log --oneline --graph -6 origin/git-lab
git log --oneline -3 origin/main
gh pr list --state merged
git branch -a
git show origin/git-lab:SPRINT.md
```
| Command | Meaning |
|---|---|
| `git fetch --prune` | Update, and drop `origin/…` branches deleted on GitHub |
| `git log … origin/git-lab` | #1 Day 1, #2 Day 3, #3 Day 2 squash commits on top of the practice history |
| `git log … origin/main` | Day 4 on top of Day 3 |
| `gh pr list --state merged` | 4 merged PRs: #1–#3 into `git-lab`, #4 into `main` |
| `git branch -a` | No `docs/…` branches left (older practice branches are untouched) |
| `git show origin/git-lab:SPRINT.md` | Read a file **from a branch** without switching to it |

## ✅ Lab self-check
| Requirement | Proof |
|---|---|
| Days 1–3 through feature branches | PRs #1, #2, #3 merged into `git-lab` |
| A PR opened and your own diff reviewed | A self-review comment on every PR |
| A deliberate conflict resolved | The Day 2 PR went from `CONFLICTING` to `MERGEABLE`; `SPRINT.md` reads 1, 2, 3 |
| `main` protected | A direct push → `GH006: Protected branch update failed` (also on `git-lab`) |
| Day 4 shipped | Merged into `main` through `docs/day04` |

---

# 🎯 Optional practice (throwaway repos)

Small tasks, one per topic. They use `~/practice/…` folders and a throwaway GitHub repo, never the sprint repo.

| # | Task | Covers |
|---|---|---|
| 1 | Create a repo with `README.md`. Watch the file go **untracked → staged → committed**. Add a `.gitignore` that hides `debug.log`. | Section 1 |
| 2 | Edit README and see the difference between `git diff` and `git diff --staged` | Section 1 |
| 3 | Look inside the last commit: its type, tree and parent. Show what `HEAD` and `main` contain. Enter and leave **detached HEAD**. | Section 2 |
| 4 | Create `feature/greeting`, commit on it, and merge it as a **fast-forward** | Section 3 |
| 5 | Change README's title on **both** `main` and `feature/title`, merge, **resolve the conflict**, and see a merge commit with **two parents** | Section 3 |
| 5b | Resolve conflicts **file by file**, then with **`-X theirs`**, **`-X ours`** and **`-s ours`**, and see **ours/theirs swap** in a rebase | Section 3.1 |
| 6 | **Rebase** a branch onto a moved `main`, see the hashes change, then **squash** 2 commits into 1 | Section 4 |
| 7 | Push to a throwaway private repo, clone it as a "teammate", get a push **rejected**, fix it, then **force-with-lease** | Section 5 |
| 8 | Add `CODEOWNERS` through a **PR** and squash-merge it | Section 6 |
| 9 | **Branch protection** on the throwaway repo | Section 6 |
| 10 | `restore`, `restore --staged`, `amend`, `reset --soft/--hard`, `reflog`, `revert`, `stash` | Section 7 |
| 11 | Commit a **fake** secret, "delete" it, and prove it's still in history | Section 7 |
| 12 | Clean up the throwaway GitHub repo and folders | — |
| 13 | **First-time setup and help**: config levels, `--show-origin`, a per-repo email | Section 1.1 |
| 14 | **`status -s`, `.gitignore` patterns, `check-ignore`, `rm --cached`, `mv`** | Section 1.2 |
| 15 | **Search history** with `--stat`, `-p`, `--author`, `--since`, `--grep`, `-S`, `--follow` | Section 8 |
| 16 | **Remotes and branch management** with a local bare "server" | Sections 3.2, 5 |
| 17 | **Tags**: lightweight vs annotated, push, delete | Section 8 |
| 18 | **Relative refs**, `branch -f`, `rebase --onto` | Sections 2.1, 4 |
| 19 | **Aliases** | Section 8 |
| 20 | A **pre-push hook** that blocks pushes to `main` (the fallback when server-side protection isn't available) | Section 6 |

## Task 1 — Three areas and file states
```bash
mkdir -p ~/practice/git-lab && cd ~/practice/git-lab
git init -b main
echo "# Git lab" > README.md
git status                       # README.md → Untracked (red)
git add README.md
git status                       # → Changes to be committed (green) = staged
git commit -m "docs: add README"
git status                       # → nothing to commit, working tree clean

touch debug.log
echo "debug.log" > .gitignore
git status                       # only .gitignore shows; debug.log is ignored
git add .gitignore
git commit -m "chore: ignore debug.log"
```
| Command | Meaning |
|---|---|
| `git init -b main` | Create the `.git` folder; the first branch is `main` |
| `git add` | Copy the change into the **staging area** |
| `git commit -m` | Save the staged snapshot with a message (Conventional Commits style) |

## Task 2 — Working tree vs staging
```bash
echo "Practice repo." >> README.md
git diff                 # shows the new line: working tree vs staging
git diff --staged        # empty: nothing staged yet
git add README.md
git diff                 # now empty
git diff --staged        # now shows the line
git commit -m "docs: describe repo"
```
**Lesson:** `git diff` = not staged yet. `git diff --staged` = what the next commit will contain.

## Task 3 — Inside Git
```bash
git log --oneline
git cat-file -t HEAD             # → commit
git cat-file -p HEAD             # → tree <hash>, parent <hash>, author, message
git cat-file -p 'HEAD^{tree}'    # → blob .gitignore, blob README.md
cat .git/HEAD                    # → ref: refs/heads/main
cat .git/refs/heads/main         # → the hash of your last commit

git switch --detach HEAD~1       # detached HEAD on the previous commit
git status                       # → "HEAD detached at …"
git switch main                  # back on the branch
```
| Part | Meaning |
|---|---|
| `cat-file -t` / `-p` | Show an object's **type** / **content** |
| `HEAD^{tree}` | The tree (folder) object of the HEAD commit |
| `.git/HEAD` | HEAD points to the **branch** `main` |
| `.git/refs/heads/main` | A branch is just a **file containing a hash** |
| `HEAD~1` | One commit before HEAD |

## Task 4 — Fast-forward merge
```bash
git switch -c feature/greeting
echo 'echo "hello"' > hello.sh
git add hello.sh
git commit -m "feat: add hello script"
git switch main
git merge feature/greeting       # → "Fast-forward"
git log --oneline --graph
git branch -d feature/greeting
```
**Lesson:** `main` hadn't moved, so the pointer just slid forward. No merge commit was made.

## Task 5 — 3-way merge and conflict
```bash
git switch -c feature/title
sed -i '1s/.*/# Git lab - feature title/' README.md
git commit -am "docs: feature title"

git switch main
sed -i '1s/.*/# Git lab - main title/' README.md
git commit -am "docs: main title"

git merge feature/title          # → CONFLICT (content): Merge conflict in README.md
git status                       # → both modified: README.md
cat README.md
```
You'll see:
```text
<<<<<<< HEAD
# Git lab - main title
=======
# Git lab - feature title
>>>>>>> feature/title
Practice repo.
```
Resolve it by writing the final version, then finish the merge:
```bash
printf '# Git lab - final title\nPractice repo.\n' > README.md
git add README.md
git commit --no-edit
git log --oneline --graph        # the two lines join at a merge commit
git cat-file -p HEAD             # → TWO "parent" lines
git branch -d feature/title
```
| Part | Meaning |
|---|---|
| `commit -am` | Stage all **tracked** modified files and commit |
| Between `<<<<<<< HEAD` and `=======` | Your side (`main`) |
| Between `=======` and `>>>>>>>` | The incoming branch |
| `--no-edit` | Accept Git's default "Merge branch…" message |

## Task 5b — Conflict strategies: file by file, -X and -s, rebase swap

### Setup: two files that will conflict, plus one change that won't
```bash
cd ~/practice/git-lab
git switch main
echo "color=red"  > app.conf
echo "title=Lab"  > site.conf
git add app.conf site.conf && git commit -m "chore: add configs"

git switch -c feature/configs
echo "color=blue"        > app.conf
echo "title=Feature Lab" > site.conf
echo "from feature"      > feature.txt          # a NON-conflicting change
git add . && git commit -m "feat: feature configs"

git switch main
echo "color=green"    > app.conf
echo "title=Main Lab" > site.conf
git commit -am "chore: main configs"
```
| Side | `app.conf` | `site.conf` | `feature.txt` |
|---|---|---|---|
| base | red | Lab | — |
| ours (`main`) | green | Main Lab | — |
| theirs (`feature/configs`) | blue | Feature Lab | from feature |

### Step 1 — File by file
```bash
git merge feature/configs                     # → CONFLICT in app.conf and site.conf
git diff --name-only --diff-filter=U          # → app.conf  site.conf
git show :1:app.conf; git show :2:app.conf; git show :3:app.conf   # red / green / blue

git checkout --ours   app.conf                # keep main  → green
git checkout --theirs site.conf               # keep feature → Feature Lab
git add app.conf site.conf
git diff --cached --check && echo "no markers left"
git commit --no-edit                          # (git merge --continue works too, but opens an editor)

cat app.conf site.conf feature.txt
```
**Expected:** `color=green`, `title=Feature Lab`, `from feature` (the non-conflicting file came in automatically).

Undo this merge so we can try the other ways (safe: not pushed):
```bash
git reset --hard HEAD~1
```

### Step 2 — Globally with `-X theirs`
```bash
git merge -X theirs --no-edit feature/configs     # no stop at all
cat app.conf site.conf feature.txt                # → blue, Feature Lab, from feature
git reset --hard HEAD~1
```

### Step 3 — Globally with `-X ours`
```bash
git merge -X ours --no-edit feature/configs
cat app.conf site.conf feature.txt                # → green, Main Lab, from feature  ← still came in!
git reset --hard HEAD~1
```

### Step 4 — The dangerous one: `-s ours`
```bash
git merge -s ours --no-edit feature/configs
cat app.conf site.conf                            # → green, Main Lab
ls feature.txt                                    # → No such file: the WHOLE branch was ignored
git log --oneline --graph -3                      # yet Git records it as merged
git reset --hard HEAD~1
```
| Step | app.conf | site.conf | feature.txt |
|---|---|---|---|
| 1 file by file | green | Feature Lab | ✅ |
| 2 `-X theirs` | blue | Feature Lab | ✅ |
| 3 `-X ours` | green | Main Lab | ✅ |
| 4 `-s ours` | green | Main Lab | ❌ missing |

### Step 5 — Ours and theirs swap during a rebase
```bash
git switch feature/configs
git rebase main                                   # → CONFLICT
git checkout --ours app.conf
cat app.conf                                      # → color=green  ← that's MAIN, not your branch!
git checkout --theirs app.conf
cat app.conf                                      # → color=blue   ← YOUR commit
git rebase --abort                                # cancel, back to before the rebase
```
**Lesson:** in a rebase, *ours* = the branch you're rebasing **onto**; *theirs* = **your** commits.

### Clean up the task
```bash
git switch main
git merge -X theirs --no-edit feature/configs     # finish for real, feature wins
git branch -d feature/configs
```

## Task 6 — Rebase and squash
```bash
git switch -c feature/notes
echo "note 1" > notes.md && git add notes.md && git commit -m "docs: note 1"
echo "note 2" >> notes.md && git commit -am "docs: note 2"

git switch main
echo "v1" > VERSION && git add VERSION && git commit -m "chore: add VERSION"

git switch feature/notes
git log --oneline --graph --all  # write down the two note hashes
git rebase main
git log --oneline --graph --all  # straight line; note commits now have NEW hashes

git reset --soft main            # undo the 2 commits but keep their changes staged
git commit -m "docs: add notes"  # 1 squashed commit
git switch main
git merge feature/notes          # → Fast-forward (thanks to the rebase)
git branch -d feature/notes
```
| Part | Meaning |
|---|---|
| `rebase main` | Replay this branch's commits on top of `main` |
| `--graph --all` | Draw every branch |
| `reset --soft main` | Move the branch back to `main`, keeping all changes staged — a simple way to squash |

**Lesson:** rebased commits are new commits. That's why you never rebase work others have already pulled.

## Task 7 — Remotes, a rejected push and force-with-lease
```bash
gh repo create git-practice --private --source=. --remote=origin --push
git remote -v                    # → origin https://github.com/<you>/git-practice.git
git branch -vv                   # → main [origin/main]  (tracking)

# The "teammate" clone
cd ~/practice
git clone https://github.com/<you>/git-practice.git git-lab-teammate
cd git-lab-teammate
echo "teammate note" >> notes.md
git commit -am "docs: teammate note"
git push

# Back to you, without pulling first
cd ~/practice/git-lab
echo "v2" > VERSION
git commit -am "chore: bump version"
git push                         # → REJECTED (fetch first)

git fetch
git status                       # → "have 1 and 1 different commits each"
git log --oneline --graph --all
git pull --rebase                # put your commit on top of the teammate's
git push                         # ✅
```
Now a **force-with-lease** push, the safe force push:
```bash
git commit --amend -m "chore: bump version to v2"   # rewrites an ALREADY pushed commit
git push                         # → rejected (history diverged)
git push --force-with-lease      # ✅ only overwrites if nobody pushed in between

cd ~/practice/git-lab-teammate
git pull                         # the teammate's history no longer matches: the pain force push causes
git fetch && git reset --hard origin/main      # how the teammate recovers
cd ~/practice/git-lab
```
| Part | Meaning |
|---|---|
| `gh repo create … --source=. --push` | Create the GitHub repo from this folder, add `origin`, push |
| `fetch` | Download only; your files are unchanged |
| `pull --rebase` | Fetch, then rebase your commits on top |
| `--force-with-lease` | Force push, but refuse if the remote changed since your last fetch |

## Task 8 — Pull request
```bash
git switch -c chore/codeowners
mkdir -p .github
echo "* @<you>" > .github/CODEOWNERS
git add .github/CODEOWNERS
git commit -m "chore: add CODEOWNERS"
git push -u origin chore/codeowners

gh pr create --base main --title "chore: add CODEOWNERS" --body "Practice PR for Day 4"
gh pr diff
gh pr review --comment --body "Looks good"   # you can't APPROVE your own PR, only comment
gh pr merge --squash --delete-branch
git switch main && git pull
git log --oneline -3
```
| Part | Meaning |
|---|---|
| `push -u` | Push and set up tracking for the new branch |
| `gh pr create` | Open the PR from the current branch into `main` |
| `gh pr merge --squash --delete-branch` | Squash-merge the PR and delete the branch, locally and on GitHub |

## Task 9 — Branch protection on the throwaway repo
The required lab already protected the real repo. This repeats it on `git-practice`. If the `PUT` answers **403 "Upgrade to GitHub Pro"**, your plan doesn't allow it on private repos: make this throwaway repo public for a few minutes (first and last lines), or skip the task.
```bash
gh repo edit <you>/git-practice --visibility public --accept-visibility-change-consequences   # only if you got 403

gh api -X PUT repos/<you>/git-practice/branches/main/protection --input - <<'EOF'
{"required_status_checks": null,
 "enforce_admins": true,
 "required_pull_request_reviews": {"required_approving_review_count": 0},
 "restrictions": null}
EOF

echo "direct" >> README.md
git commit -am "docs: direct push test"
git push          # → REJECTED: protected branch, changes must be made through a pull request
git reset --hard origin/main     # drop the local test commit

gh repo edit <you>/git-practice --visibility private --accept-visibility-change-consequences   # only if you made it public
```
| Part | Meaning |
|---|---|
| `enforce_admins: true` | Rules apply to you too, as the owner |
| `required_pull_request_reviews` | All changes must go through a PR |

## Task 10 — Undoing things
```bash
# restore: discard an unstaged change
echo "oops" >> README.md
git restore README.md

# restore --staged: unstage, then discard
echo "oops" >> README.md
git add README.md
git restore --staged README.md   # back to "not staged"
git restore README.md            # change gone

# amend: fix the last (unpushed) commit
echo "a" > a.txt && git add a.txt && git commit -m "chore: add a"
echo "b" > b.txt && git add b.txt
git commit --amend -m "chore: add a and b"     # still ONE commit

# reset --soft: undo the commit, keep the changes staged
git reset --soft HEAD~1
git status                       # a.txt and b.txt staged
git commit -m "chore: add a and b"

# reset --hard: the commit and its changes are gone…
git reset --hard HEAD~1
ls                               # a.txt, b.txt gone
# …reflog: get them back
git reflog                       # find "commit: chore: add a and b"
git reset --hard 'HEAD@{1}'
ls                               # back!

# revert: undo a PUSHED commit safely
git push
git revert HEAD --no-edit        # a NEW commit that removes a.txt and b.txt
git push
git log --oneline -3

# stash: shelve work in progress
echo "wip" >> README.md
git stash
git status                       # clean
git stash pop                    # wip is back
git restore README.md
```

## Task 11 — Secrets stay in history
⚠️ Use a **fake** value only.
```bash
echo "API_KEY=FAKE-1234-not-a-real-key" > .env
git add .env && git commit -m "chore: add config"
git rm .env && git commit -m "chore: remove config"
ls .env                          # gone from the folder…
git show HEAD~1:.env             # …but still in history!
git log -p -S "FAKE-1234" --oneline   # search all of history for the string

# Not pushed yet, so rewriting is allowed: drop both commits
git reset --hard HEAD~2
echo ".env" >> .gitignore
git commit -am "chore: ignore .env"
```
**Lesson:** if this had been **pushed**, deleting it wouldn't help. The fix is to **rotate the secret** (revoke it and make a new one).

## Task 12 — Cleanup of the throwaway GitHub repo
```bash
gh auth refresh -h github.com -s delete_repo     # one-time: allow gh to delete repos
gh repo delete <you>/git-practice --yes
rm -rf ~/practice/git-lab ~/practice/git-lab-teammate
```

## Task 13 — First-time setup and help
```bash
git config --global user.name                    # check what's set
git config --global user.email
git config --global init.defaultBranch main
git config --global core.editor nano
git config --list --show-origin | head            # every setting and the file it came from

mkdir -p ~/practice/git-extra && cd ~/practice/git-extra && git init
git config user.email work@example.com            # LOCAL: this repo only
git config --show-origin user.email               # → file:.git/config  work@example.com
git config --unset user.email
git config --show-origin user.email               # → back to ~/.gitconfig

git switch -h                                     # short usage
git help switch                                   # full manual (q to quit)
```
| Part | Meaning |
|---|---|
| `--global` | `~/.gitconfig`, for every repo of yours |
| no flag (inside a repo) | `.git/config`, this repo only — beats global |
| `--show-origin` | Which file a value comes from |
| `--unset` | Remove a setting at that level |

## Task 14 — Short status, ignore patterns, rm --cached, mv
```bash
cd ~/practice/git-extra
echo "# extra" > README.md && git add . && git commit -m "docs: init"
mkdir -p logs build src
touch app.log logs/a.log keep.log build/out.bin src/main.py src/tmp.py
cat > .gitignore <<'EOF'
*.log
!keep.log
build/
**/tmp.py
EOF
git status -s                    # → ?? .gitignore   ?? keep.log   ?? src/
git status -s -uall              # list files inside folders: ?? src/main.py
git check-ignore -v app.log logs/a.log build/out.bin src/tmp.py
git add . && git commit -m "chore: add files and ignore rules"

echo change >> README.md
echo x > new.txt && git add new.txt
git status -s                    # → " M README.md"  and  "A  new.txt"
git commit -am "docs: change README, add new.txt"

git add -f app.log && git commit -m "chore: track a log by mistake"
git rm --cached app.log && git commit -m "chore: stop tracking app.log"
ls app.log                       # still on disk; no longer tracked

git mv src/main.py src/app.py
git status -s                    # → R  src/main.py -> src/app.py
git commit -m "refactor: rename main.py to app.py"
```
| Part | Meaning |
|---|---|
| `?? src/` | A whole untracked folder is shown as one line; `-uall` lists each file |
| ` M` vs `A ` | Column 1 = staged, column 2 = working tree |
| `check-ignore -v` | Prints `.gitignore:<line>:<pattern>` for each ignored file |
| `add -f` | Force-add an ignored file (how logs get committed by mistake) |
| `rm --cached` | Untrack but keep the file |
| `R ` | A staged rename |

## Task 15 — Search history
```bash
git log --stat -1                                 # files changed by the last commit
git log -p -1                                     # its full diff
git log --oneline --author="$(git config user.name)"
git log --oneline --since="1 hour ago"
git log --oneline --grep="ignore"                 # message contains "ignore"
git log --oneline -S "change"                     # commits that added/removed "change"
git log --pretty=format:'%h %an %ar %s' -3
git log --oneline -- src/                         # only commits touching src/
git log --oneline --follow -- src/app.py          # follows the rename back to main.py
```

## Task 16 — Remotes and branch management (local "server")
```bash
git init --bare ~/practice/extra-remote.git       # a bare repo acts like GitHub
git remote add origin ~/practice/extra-remote.git
git push -u origin main
git remote show origin
git remote rename origin backup && git remote -v
git remote rename backup origin

git switch -c feature/a && git commit --allow-empty -m "feat: a" && git switch main
git switch -c feature/b && git commit --allow-empty -m "feat: b" && git switch main
git merge feature/a
git branch -v
git branch --merged                               # → feature/a, main
git branch --no-merged                            # → feature/b

git branch -m feature/b feature/b-renamed
git push -u origin feature/b-renamed
git branch -vv                                    # → [origin/feature/b-renamed]
git branch --unset-upstream feature/b-renamed
git branch --set-upstream-to=origin/feature/b-renamed feature/b-renamed

git push origin --delete feature/b-renamed        # delete it on the "server"
git fetch --prune && git branch -a                # stale origin/feature/b-renamed gone
git branch -d feature/a                           # merged → deleted
git branch -d feature/b-renamed                   # → error: not fully merged
git branch -D feature/b-renamed                   # force

git remote add mirror ~/practice/extra-remote.git && git remote
git remote remove mirror && git remote
```
| Part | Meaning |
|---|---|
| `init --bare` | A repo with no working tree — exactly what a server holds |
| `commit --allow-empty` | A commit with no file changes, handy for practice |
| `--unset-upstream` / `--set-upstream-to` | Remove / set which remote branch this one tracks |

## Task 17 — Tags
```bash
git tag v0.1                                      # lightweight
git tag -a v1.0 -m "First release"                # annotated
git tag -a v0.9 -m "Late tag" HEAD~2              # tag an older commit
git tag
git tag -l "v1*"
git cat-file -t v0.1                              # → commit (just a pointer)
git cat-file -t v1.0                              # → tag    (a real object)
git show v1.0 --no-patch                          # tagger, date, message, then the commit

git push origin v1.0                              # one tag
git push origin --tags                            # all tags
git ls-remote --tags origin

git tag -d v0.1 && git push origin --delete v0.1
git switch --detach v1.0 && git status | head -1  # → HEAD detached at v1.0
git switch main
```

## Task 18 — Relative refs, branch -f, rebase --onto
```bash
git switch -c side && git commit --allow-empty -m "side work" && git switch main
git commit --allow-empty -m "main work"
git merge --no-edit side                          # a merge commit with 2 parents

git log --oneline -1 HEAD^                        # → main work   (first parent)
git log --oneline -1 HEAD^2                       # → side work   (second parent)
git log --oneline -1 HEAD~2                       # two back along first parents
git log --oneline -1 HEAD^^                       # same as HEAD~2

git branch -f side HEAD~3                         # force-move the "side" pointer
git log --oneline -1 side
git branch -f side main                           # move it back

git switch -c server && git commit --allow-empty -m S1 && git commit --allow-empty -m S2
git switch -c client && git commit --allow-empty -m C1 && git commit --allow-empty -m C2
git switch main && git commit --allow-empty -m "main moves"
git rebase --onto main server client              # move ONLY C1, C2 onto main
git log --oneline -4 client                       # → C2, C1, main moves, …  (no S1/S2)
git switch main
```

## Task 19 — Aliases
```bash
git config --global alias.st "status -s"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.last "log -1 HEAD --stat"
git config --global alias.unstage "restore --staged --"

echo y > y.txt && git add y.txt
git st                                            # → A  y.txt
git unstage y.txt && git st                       # → ?? y.txt
rm y.txt
git lg | head -5
git last
git config --global --get-regexp '^alias\.'
```
## Task 20 — A pre-push hook (the fallback guard)
When server-side protection isn't available (403 "Upgrade"), a **hook** — a script Git runs before every push — can refuse pushes to protected branches on your machine.
```bash
cd ~/practice/git-extra
cat > .git/hooks/pre-push <<'EOF'
#!/usr/bin/env bash
# pre-push - block direct pushes to protected branches.
protected=("refs/heads/main")
# Git sends one line per ref being pushed: <local ref> <local sha> <remote ref> <remote sha>
while read -r _ _ remote_ref _; do
  for branch in "${protected[@]}"; do
    if [[ "$remote_ref" == "$branch" ]]; then
      echo "pre-push: direct pushes to ${branch#refs/heads/} are blocked. Push a branch and open a PR." >&2
      exit 1
    fi
  done
done
exit 0
EOF
chmod +x .git/hooks/pre-push
shellcheck .git/hooks/pre-push && echo "shellcheck clean"

git commit --allow-empty -m "test: direct push"
git push origin main               # → pre-push: direct pushes to main are blocked…
git switch -c test/hook && git push -u origin test/hook   # a branch is allowed
git push origin main --no-verify   # skips the hook — why it's a guard rail, not security
```
| Part | Meaning |
|---|---|
| `.git/hooks/pre-push` | Git runs this file before every push; a non-zero exit cancels the push |
| `while read -r _ _ remote_ref _` | One line per pushed ref; keep only field 3, the remote branch |
| `${branch#refs/heads/}` | Strip the prefix so the message says just `main` |
| `--no-verify` | Skips hooks — server-side protection can't be skipped this way |
| Sharing it | `.git/hooks` isn't versioned: commit a copy (e.g. `.githooks/pre-push`) and have each clone copy it in or run `git config core.hooksPath .githooks` |

Clean up: `rm -rf ~/practice/git-extra ~/practice/extra-remote.git`

---

## ✅ Self-check for the optional practice
| Section | Proof |
|---|---|
| 1 / 1.1 / 1.2 | A file moved untracked → staged → committed; `--show-origin` showed local beating global; `check-ignore -v` named the rule |
| 2 / 2.1 | `.git/refs/heads/main` held a hash; `HEAD^2` showed the merged-in branch |
| 3 / 3.1 / 3.2 | Fast-forward and 3-way merges; `-X ours` kept `feature.txt` while `-s ours` dropped it; `--no-merged` warned before `-D` |
| 4 | Hashes changed after rebase; `--onto` moved only C1 and C2 |
| 5 | A push was **rejected**, then succeeded after `pull --rebase` |
| 6 | A PR was squash-merged with `gh` |
| 7 | `reflog` brought back a commit after `reset --hard` |
| 8 | `cat-file -t` showed `commit` for a lightweight tag and `tag` for an annotated one |

## Lessons
| # | Lesson |
|---|---|
| 1 | A commit is a **snapshot**; a branch is just a **pointer** to one; a tag is a pointer that **never moves**. |
| 2 | Set your name and email once (`--global`); override per repo when needed (local wins). |
| 3 | The staging area lets one commit hold **one logical change**; `status -s` shows both columns at a glance. |
| 4 | Fast-forward moves a pointer; a 3-way merge creates a commit with two parents (`^1`, `^2`). |
| 5 | Resolve conflicts by hand when both sides matter; `--ours`/`--theirs` per file; `-X` for the whole merge. Never confuse `-X ours` with `-s ours`, and remember the swap in a rebase. |
| 6 | Rebase rewrites history — only on your own, unshared work. A pushed PR branch: **merge `main` into it**. |
| 7 | Pull before you push; `--force-with-lease`, never plain `--force`, on anything shared. |
| 8 | Every change to `main` goes through a **PR** that you **review yourself first**. GitHub branch protection enforces it on the server (it worked on this private repo); a pre-push hook is the local fallback. |
| 8b | One branch per task: after a merge, update the base, delete the old branch, start a **new** one — and check `git status -s` is clean first. |
| 9 | `revert` for pushed work, `reset` for local work, `reflog` when something seems lost. |
| 10 | Secrets live forever in history — **rotate**, don't just delete. |
