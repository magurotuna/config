---
name: plan-review
description: Review the current plan by auto-selecting appropriate reviewer agents based on project characteristics.
allowed-tools: Bash(codex exec *)
---

# Plan Review

Review the latest plan file by analyzing project characteristics, selecting appropriate reviewer agents, and running them in parallel.

## Prerequisites

- A plan file must already exist (created via Plan mode)
- Reviewer agents must be defined in `~/.claude/agents/`

## Arguments

| Argument   | Required | Description                                             |
| ---------- | -------- | ------------------------------------------------------- |
| agent-name | No       | Explicit agent name. Omit for auto-selection (recommended) |

## Execution Flow

### Phase 1: Detect the Latest Plan File

```bash
ls -t ./plans/*.md 2>/dev/null | head -1
```

If no file is found, report an error and stop.
Use the Read tool to load the detected plan file.

### Phase 2: Reviewer Selection

If an agent name is provided as an argument, use only that agent (manual mode).

If no argument is given (recommended), auto-select reviewers based on project signals.

#### 2a: Project Signal Detection

Collect the following signals **in parallel**:

| Signal             | Detection Method                                         |
| ------------------ | -------------------------------------------------------- |
| Rust project       | `Cargo.toml` exists, or `*.rs` files present             |
| Go project         | `go.mod` exists, or `*.go` files present                 |
| TypeScript project | `tsconfig.json` exists, or `*.ts` files present          |
| codex CLI available| `which codex` succeeds                                   |
| Refactoring-related| Plan body contains refactoring keywords (see below)      |
| Test infrastructure| Test files, test config, or test directories exist        |

**Refactoring keywords** (checked against plan body):

- refactor / refactoring / duplication / DRY / extract / consolidate / deduplicate

**Test infrastructure detection** — at least one primary signal:

- Test files: `*.test.ts`, `*.spec.ts`, `*.test.tsx`, `*.spec.tsx`, `*.test.js`, `*.spec.js`, `*_test.go`, `*_test.rs`
- Test configs: `vitest.config.*`, `jest.config.*`, `playwright.config.*`
- Test directories: `tests/`, `__tests__/`, `test/`

#### 2b: Reviewer Matching Rules

Based on collected signals, select reviewers:

| Condition                         | Reviewer to Launch  |
| --------------------------------- | ------------------- |
| codex CLI is available            | `codex-reviewer`    |

<!-- Future reviewers can be added here:
| Rust project detected             | `rust-reviewer`     |
| Refactoring keywords in plan      | `similarity`        |
| Test infrastructure exists        | `tdd-reviewer`      |
-->

- If multiple conditions match, launch **all** matching reviewers (in parallel).
- If no conditions match, notify the user and suggest manual agent selection.

#### 2c: Display Selection Results

Before launching, show the selection summary:

```
Project analysis:
  - codex CLI: Y (available)

Launching reviewers: codex-reviewer
```

### Phase 3: Parallel Review Execution

Launch **all selected agents in parallel** via the Agent tool.

Prompt passed to each agent:

```
Please review the following Plan file.
Based on your expertise, provide feedback on:
1. Technical accuracy
2. Potential issues and risks
3. Improvement suggestions
4. Overlooked considerations

---

Plan File: <path>

---

<content>
```

**Important**: Agent tool calls are independent — always invoke multiple agents in a **single message** for true parallelism.

### Phase 4: Result Aggregation & Report

Aggregate all reviewer results in this format:

```
=== Plan Review Results ===

--- codex-reviewer ---
[feedback from codex-reviewer]

=== Summary ===
Cross-cutting summary of all reviewer feedback, with high-severity issues listed first.
```

## Reviewer Registry

| Agent Name      | Auto-Select Condition                | Expertise                              |
| --------------- | ------------------------------------ | -------------------------------------- |
| codex-reviewer  | codex CLI is available               | General architecture & design review   |

<!-- To add a new reviewer:
1. Create the agent in ~/.claude/agents/<name>.md
2. Add a row to this table
3. Add a matching rule in Phase 2b
-->

## Error Handling

| Situation                            | Response                                          |
| ------------------------------------ | ------------------------------------------------- |
| No plan file found                   | Notify that the plans directory has no files       |
| No matching reviewers in auto-select | List available agents and suggest manual selection |
| Specified agent not found            | List available agents and report error             |
| Some agents fail                     | Report successful results and note failures        |

## Notes

- Plans directory: `./plans` (relative to project root)
- Latest file is auto-detected — no path input required
- Both signal collection and review execution are **parallelized** for speed
- Manual mode is fully supported for backward compatibility
- To add a new reviewer, update the Reviewer Registry table and the Phase 2b matching rules
