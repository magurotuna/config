---
name: plan-refine
description: Iteratively refine the current Plan by applying Codex review feedback until Codex has no more issues to raise.
allowed-tools: Bash(codex exec *), Bash(ls *), Read, Edit
---

# Plan Refine

Improve the latest plan file by running Codex review in a loop: each round, apply Codex's feedback to the plan and re-review. Stop when Codex signals no further issues, or when the iteration cap is reached.

## Prerequisites

- A plan file must already exist under `./plans/` (created via Plan mode)
- The `codex` CLI must be installed and authenticated (`which codex` succeeds)

## Arguments

| Argument        | Required | Default | Description                                                       |
| --------------- | -------- | ------- | ----------------------------------------------------------------- |
| plan-name       | No       | —       | Plan filename to refine (with or without `.md`). If omitted, ask the user to pick one interactively. |
| max-iterations  | No       | 8       | Hard cap on review rounds to prevent runaway loops                |

## Execution Flow

### Phase 1: Resolve the Plan File

Resolve `<plan_path>` using one of the two paths below.

#### 1a: Plan name provided

If the user passed a `plan-name` argument:

1. Normalize it: strip any leading `./plans/`, then append `.md` if the argument has no extension.
2. Check that `./plans/<normalized>` exists. If it does not, list the available plans under `./plans/` and stop with a clear error — do NOT silently fall back to auto-selection.
3. Set `<plan_path>` to the resolved path.

#### 1b: No plan name provided — ask the user

1. List candidates:

   ```bash
   ls -t ./plans/*.md 2>/dev/null
   ```

2. If the list is empty, report that `./plans/` has no markdown files and stop.
3. If exactly one candidate exists, use it directly and tell the user which file was picked.
4. If two or more candidates exist, use `AskUserQuestion` to let the user choose. Present the filenames (most recently modified first) as options, with a short preview (e.g. the plan's H1 title) as the option description when easily available. Wait for the user's answer; do NOT guess.

Once `<plan_path>` is set, use the Read tool to load it before entering the refinement loop.

### Phase 2: Refinement Loop

Run the following cycle up to `max-iterations` times:

```
+-> Run Codex review on <plan_path>
|   |
|   v
|   Parse review output
|   |
|   +--> Contains "NO_FURTHER_ISSUES" marker? --> exit loop
|   |
|   v
|   Edit the plan to incorporate feedback
|   |
|   v
|   Re-read the updated plan
|   |
+-- Next iteration
```

#### 2a: Codex Review Invocation

Invoke Codex directly with a prompt that forces a deterministic termination signal. Use `--sandbox read-only` so Codex cannot modify the plan itself — only Claude edits the plan based on the feedback.

```bash
codex exec --sandbox read-only "$(cat <<'EOF'
You are reviewing a software implementation plan. Read the file at <plan_path> and critique it from these angles:

1. Technical correctness and feasibility
2. Missing steps, edge cases, or error handling
3. Inconsistencies or ambiguities
4. Risks, unclear ownership, or untested assumptions
5. Concrete improvements (name specific sections / lines)

Output format:
- If substantive issues remain, list them as a numbered list. Each item: (a) what is wrong, (b) why it matters, (c) a concrete suggested fix. Do not include the marker below.
- If the plan is solid and you have no remaining substantive issues, output exactly one line: NO_FURTHER_ISSUES
- Do not nitpick wording. Only raise issues that would materially affect implementation quality.
EOF
)" < /dev/null
```

**Critical: the `< /dev/null` redirect is mandatory.** When stdin is not a TTY (which is always the case inside Claude Code's Bash tool), `codex exec` treats stdin as piped input to be appended to the prompt and will block forever waiting for EOF. Redirecting from `/dev/null` closes stdin immediately so Codex stops waiting and proceeds. Never omit this, even when using `run_in_background`.

Substitute `<plan_path>` with the actual path. Do NOT use `-m` — let Codex pick its default model.

**Run the command as a background Bash job** (`run_in_background: true`) to avoid the 10-minute foreground timeout — long reviews can exceed that cap. After starting the job:

1. Wait for the background-job completion notification from the harness. Do NOT poll or sleep in a loop; the notification arrives automatically.
2. Once notified, read the job's stdout via the background-job handle and use it as the review output.
3. If the job exits non-zero, treat it as a Codex failure per the Safety Guards below (report exit code and stderr; do not retry).

#### 2b: Termination Check

- If stdout contains the exact line `NO_FURTHER_ISSUES`, exit the loop successfully.
- Otherwise, treat stdout as the review feedback and continue.

#### 2c: Apply Feedback

For each substantive issue in the review:

1. Decide whether the feedback is actionable and correct. If a suggestion conflicts with explicit decisions already recorded in the plan, note the tension in the plan rather than silently reversing the decision.
2. Use the Edit tool to update `<plan_path>` — clarify ambiguities, add missing steps, tighten error handling, resolve inconsistencies.
3. After editing, re-read the file so the next Codex round sees the current version from disk.

#### 2d: Safety Guards

- **Iteration cap**: never exceed `max-iterations` rounds (default 8). If hit, exit the loop and report that Codex still had open issues.
- **No-progress detection**: if two consecutive rounds return nearly identical feedback, exit the loop and surface the stuck issue to the user rather than looping fruitlessly.
- **Codex failure**: if `codex exec` returns a non-zero exit code, stop the loop and report the exit code plus stderr. Do not silently retry.

### Phase 3: Completion Report

Report to the user in this format:

```
=== Plan Refine Complete ===

Plan file: <plan_path>
Rounds completed: <N>
Termination reason: <no-further-issues | max-iterations-reached | no-progress | codex-error>

Key changes applied:
- <bullet point per substantive edit>

Final Codex verdict:
<last review output, or "NO_FURTHER_ISSUES">
```

## Error Handling

| Situation                     | Response                                                   |
| ----------------------------- | ---------------------------------------------------------- |
| No plan file found            | Notify that `./plans/` has no markdown files and stop      |
| `codex` CLI not on PATH       | Instruct the user to install and authenticate `codex`      |
| `codex exec` runs very long   | Expected — it's backgrounded. Keep waiting for the completion notification, don't kill it |
| `codex exec` hangs with 0 bytes output | Almost always a missing `< /dev/null`. Kill it, add the stdin redirect, retry |
| Authentication error          | Guide the user to check `codex login` status               |
| Plan edit fails               | Report the error and stop — do not continue reviewing stale content |

## Notes

- Plans directory: `./plans/` (relative to project root)
- Only the latest plan file by modification time is refined
- Codex runs `--sandbox read-only`: it cannot modify the plan — only Claude does, based on Codex feedback
- The `NO_FURTHER_ISSUES` sentinel is the sole termination signal; never infer "good enough" from vibes
- Prefer this skill *after* `/dig` (which fills gaps via user Q&A) and *before* `/plan-review` (which produces a final report)
