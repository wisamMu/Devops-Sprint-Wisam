[⬅ Back to index](../README.md)

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

> **Lab:** the Git workflow lab (branch protection, feature branches, PRs, a deliberate conflict) and the 20 optional practice tasks are on the **`git-lab`** branch: `day04/lab.md`.
