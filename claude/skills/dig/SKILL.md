---
name: dig
description: Iteratively ask clarifying questions to enrich the current Plan before review.
allowed-tools: Skill(plan-review)
---

# Dig

Read the current Plan file, identify missing information needed for implementation, and iteratively ask the user clarifying questions via AskUserQuestion. Incorporate answers into the Plan, re-analyze, and repeat until sufficiently detailed.

## Prerequisites

- A plan file must already exist (created via Plan mode)

## Execution Flow

### Phase 1: Detect the Latest Plan File

```bash
ls -t ./plans/*.md 2>/dev/null | head -1
```

If no file is found, report an error and stop.
Use the Read tool to load the detected plan file.

### Phase 2: Gap Analysis

Analyze the plan from the following perspectives and identify information gaps that would block implementation:

#### Analysis Perspectives

1. **Technical Design Decisions**
   - Are library / framework choices explicitly stated?
   - Are data structures and algorithms clearly chosen?
   - Is the API design (endpoints, request/response shapes) concrete?

2. **Business Requirements Clarity**
   - Are edge-case behaviors defined?
   - Are error-state user experiences decided?
   - Are input constraints and validation rules clear?
   - Are success / failure criteria defined?

3. **Consistency with Existing Code**
   - Is compatibility with existing APIs and type definitions considered?
   - Are naming conventions and coding standards consistent?
   - Are dependencies on existing modules clear?

4. **Implementation Specificity**
   - Is each step broken down to an implementable granularity?
   - Are target files for creation / modification identified?
   - Is the test strategy (what to test and how) clear?

### Phase 3: Question Cycle

When gaps are found, repeat this cycle:

```
+-> Identify gaps
|   |
|   v
|   Ask 1-3 related questions via AskUserQuestion
|   |
|   v
|   Receive the user's answers
|   |
|   v
|   Update the Plan file with the Edit tool
|   |
|   v
|   Re-read and re-analyze the updated Plan
|   |
+-- If gaps remain, repeat
```

#### Question Rules

- **1-3 related questions per round** — too many at once is overwhelming.
- **Be specific**: instead of "How will you design this?", ask "Should the return type be `Result<T, E>` or `Option<T>`?" — provide choices and concrete examples.
- **Leverage the codebase**: read relevant code before asking. Do not ask about information already available in the code.
- **Prioritize**: ask about implementation blockers first.

#### Exit Conditions

Stop the cycle when either:

1. All analysis perspectives are sufficiently covered.
2. The user signals completion ("that's enough", "looks good", etc.).

### Phase 4: Completion Report & Auto-Review

After the cycle ends, report:

```
=== Dig Complete ===

Updated Plan file: <path>

Information added:
- [key decisions added, as bullet points]

Running /plan-review automatically...
```

Then invoke `/plan-review` via the Skill tool automatically.

## Error Handling

| Situation              | Response                                          |
| ---------------------- | ------------------------------------------------- |
| No plan file found     | Notify that the plans directory has no files       |
| Plan file update fails | Report the error and suggest manual editing        |

## Notes

- Plans directory: `./plans` (relative to project root)
- The latest file is auto-detected — no path input required from the user
- Use before `/plan-review` to improve review quality
- Read related code before asking questions to avoid asking about things already evident in the codebase
