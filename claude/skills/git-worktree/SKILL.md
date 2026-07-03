---
name: git-worktree
description: Create, switch, list, and delete git worktrees with `git wt` (the git-wt CLI). Use when working on multiple branches in parallel, isolating an experiment in its own checkout, or whenever the user mentions worktrees or `git wt`.
allowed-tools: Bash
---

# Working with Git Worktrees (`git wt`)

`git wt` is the `git-wt` CLI (a `git worktree` wrapper). A worktree is a separate
working directory with its own checked-out branch that shares the repository's
single object store. Use worktrees to work on several branches at once without
stashing or re-checking-out.

## This machine's setup (from git config)

- `wt.basedir = ../{gitroot}-wt` -> worktrees live next to the repo at
  `../<reponame>-wt/<branch>` (e.g. `../config-wt/feature-x`).
- `wt.copyignored` and `wt.copyuntracked` are on -> gitignored files (like `.env`)
  and untracked files are copied into each new worktree, so it can run immediately.
  Be mindful that this includes secrets.

## CRITICAL: directory switching does NOT work in agent shells

`git wt <branch>` is meant to `cd` you into the worktree, but that `cd` is performed
by a `git()` shell-wrapper function installed via `eval "$(git-wt --init zsh)"`. The
wrapper reads the worktree path from the **last line** of output and changes the
interactive shell's directory.

Agent/tool Bash calls run in **non-interactive subshells that do not load that
wrapper**, so `git wt <branch>` will create/select the worktree but your shell's
working directory will NOT change. Never assume you moved.

Always capture the path and act on it explicitly, in a single Bash call:

```bash
dir=$(git wt <branch> --nocd 2>/dev/null | tail -1)
cd "$dir" && <your commands>      # cd within the same Bash invocation
# or, without cd:
git -C "$dir" status
```

`--nocd` plus `tail -1` is the robust pattern: when creating, `git wt` prints status
lines ("Preparing worktree...") followed by the path; when selecting an existing
worktree it prints only the path. The last line is always the worktree path.

## Commands

- **List:** `git wt` (human table) or `git wt --json` (machine-readable; each entry
  has `path`, `branch`, `head`, `bare`, `current`). Prefer `--json` when parsing.
- **Create or switch:** `git wt <branch>` — selects the worktree/branch if it already
  exists, otherwise creates the worktree **and** branch.
- **Create from a start-point:** `git wt <branch> <start-point>`, e.g.
  `git wt fix-bug origin/main` to branch off the latest remote main.
- **Delete (safe):** `git wt -d <name>...` — removes the worktree and branch only if
  the branch is merged.
- **Force delete:** `git wt -D <name>...` — removes regardless of merge state.
- The default branch (`main`/`master`) is protected from deletion; the worktree is
  removed but the branch is preserved. Use `--allow-delete-default` to override.

## Footgun: every non-flag argument is a worktree name

`git wt` has no verb subcommands. ANY non-flag word is treated as a branch/worktree
name to create. `git wt rm foo` does NOT remove anything — it creates worktrees named
`rm` and `foo`. To delete, you MUST use the `-d`/`-D` flags. Likewise `git wt help`
creates a worktree called `help`; use `git wt -h` for usage.

## Typical agent workflow

```bash
# 1. Start an isolated task on its own branch off the latest main
dir=$(git wt feature/my-task origin/main --nocd 2>/dev/null | tail -1)
cd "$dir"

# 2. Do the work, commit, push from inside $dir ...

# 3. Clean up once merged — run from a DIFFERENT worktree (e.g. the main repo),
#    never from inside the worktree being deleted.
cd <main-repo-dir>
git wt -d feature/my-task
```

## Gotchas

- Do not delete the worktree you are currently inside; run the delete from another
  worktree (such as the primary repo directory).
- `wt.hook` commands run only on **create**, not when switching to an existing
  worktree. (No hooks are configured on this machine by default.)
- Two worktrees cannot check out the same branch simultaneously.
