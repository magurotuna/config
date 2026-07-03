---
name: output-learn
description: Extract technical learnings from the session and save them to the learn repository.
---

# Output Learn

Extract and organize technical learnings from the current Claude Code session and save them to the `learn` repository.

## Output Destination

```
@homeDirectory@/Repo/github.com/magurotuna/learn/<category>/<topic-slug>.md
```

## Execution Flow

### Phase 1: Session Analysis

Analyze the conversation history and extract technical learnings.

Extraction targets:

- **New knowledge**: newly learned concepts, APIs, library usage
- **Design decisions**: architecture choices, pattern application rationale
- **Troubleshooting**: error investigation processes and solutions
- **Best practices**: efficient implementation methods, recommended patterns
- **Code examples**: reusable snippets, implementation patterns

If no learnings are found, notify the user that the session lacks technical content and stop.

### Phase 2: Category Selection

Auto-detect candidate categories from keywords and confirm with the user via AskUserQuestion.

Example categories:

| Category         | Scope                                  |
| ---------------- | -------------------------------------- |
| `typescript`     | TypeScript language features, types    |
| `rust`           | Rust language, cargo, crates           |
| `go`             | Go language, modules                   |
| `nix`            | Nix, NixOS, home-manager, flakes      |
| `testing`        | Test methodology, frameworks           |
| `git`            | Git operations, workflows              |
| `cli`            | CLI development, command-line tools    |
| `architecture`   | Design patterns, architecture          |
| `library/<name>` | Specific library usage                 |
| `devops`         | CI/CD, infrastructure                  |
| `k8s`            | Kubernetes, Helm, k9s                  |
| `performance`    | Performance optimization               |

```
Via AskUserQuestion:
- Present detected category candidates
- Allow custom category input
```

### Phase 3: Markdown Generation

Generate a markdown file based on this template.

Filename: `<topic-slug>.md` (lowercase kebab-case)

**Template:**

````markdown
# <Title>

## Summary

<1-2 sentence overview of the learning>

## Background

<What situation led to this learning>

## What I Learned

### <Subtopic>

<Detailed explanation>

```<language>
// code example
```

## Key Takeaways

- <Key point 1>
- <Key point 2>

## References

- [Link text](URL)
````

### Phase 4: User Confirmation

Display a preview of the generated markdown and ask for confirmation via AskUserQuestion.

Confirmation items:

1. **Preview**: show the full generated markdown
2. **Duplicate check**: warn if a file with the same name exists

```
Via AskUserQuestion:
- Approve and save
- Request modifications (provide instructions)
- Change filename
- Cancel
```

If a file with the same name exists:

```
Via AskUserQuestion:
- Overwrite
- Save with a different name (add suffix)
- Append to existing file
- Cancel
```

### Phase 5: Save & Push

After approval, save and push:

```bash
LEARN_REPO="@homeDirectory@/Repo/github.com/magurotuna/learn"

if [ ! -d "$LEARN_REPO" ]; then
  echo "learn repository not found"
  echo "Run: ghq get magurotuna/learn"
  exit 1
fi

# Create category directory if needed
mkdir -p "$LEARN_REPO/<category>"

# Write the markdown file via the Write tool

# Git operations
cd "$LEARN_REPO"
git add "<category>/<topic-slug>.md"
git commit -m "Add: <title>"
git push origin main
```

## Error Handling

| Situation                    | Response                                              |
| ---------------------------- | ----------------------------------------------------- |
| learn repo not cloned        | Suggest running `ghq get magurotuna/learn`            |
| No technical learnings found | Notify that the session lacks technical content, stop  |
| Git push fails               | Show the error and suggest manual resolution           |
| Duplicate filename           | Offer overwrite / rename / append via AskUserQuestion  |
| Directory creation fails     | Report permission error                                |

## Notes

- Analyze the entire conversation history; best used toward the end of a session
- When multiple learnings exist, pick the most important one
- Keep code examples minimal; focus on explanation
- Only include reference URLs that were mentioned during the session
