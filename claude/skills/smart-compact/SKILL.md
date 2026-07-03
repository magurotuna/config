---
name: smart-compact
description: Analyze session context and generate a targeted prompt for /compact to preserve important information.
disable-model-invocation: true
---

# Smart Compact

Analyze the session context and generate a user-tailored `/compact` prompt that preserves the most important information.

## Execution Flow

### Phase 1: Session Context Analysis

Analyze the full conversation history and extract:

- **Active tasks**: current implementation, fix, or investigation in progress
- **Key technical decisions**: architecture, library, or design choices made
- **Unresolved issues**: remaining errors, bugs, or open questions
- **File change history**: files modified/created during the session and their purpose
- **Context-dependent information**: prerequisites and constraints needed for follow-up work

Display the analysis as concise bullet points.

### Phase 2: User Interview

Based on the Phase 1 analysis, ask the user via AskUserQuestion what to preserve.

**Question generation rules:**

- Dynamically generate choices based on the session content
- Choices must include session-specific context (task names, file names, tech stack, etc.)
- Use multiSelect: true for multiple selections
- Provide 2-4 choices

**Question template:**

```
Question: "Which information should /compact prioritize preserving?"
header: "Preserve"
multiSelect: true

Example choices (dynamically generated from session):
- "Implementation progress and remaining work for <specific task>"
- "Error investigation context around <filename>"
- "Design decisions and rationale for <technology>"
- "API specification and type definitions for <feature>"
```

**Important**: Generate concrete choices derived from the session analysis, not generic presets.

### Phase 3: Prompt Generation

Based on the user's selections, generate a `/compact` prompt.

**Prompt generation guidelines:**

1. Prioritize items the user selected
2. Include the minimum context needed to continue the current task
3. Include specific file names, function names, error messages, and other identifiers
4. Frame as "what to preserve" rather than "what to discard"

**Output format:**

```
Please compress the context while prioritizing the following information:

1. [Specific content of preserve item 1]
2. [Specific content of preserve item 2]
3. [Specific content of preserve item 3]

Preserve the following accurately:
- [Important identifiers, paths, commands, etc.]
```

### Phase 4: Confirmation & Execution Guidance

Present the generated prompt and confirm via AskUserQuestion.

```
Via AskUserQuestion:
- "Run compact with this prompt?"
  - "Run it" — display the command
  - "Modify" — apply modifications
  - "Cancel"
```

**On approval:**

Output the command in a copyable format:

````
Copy and run the following command:

```
/compact <generated prompt>
```
````

**On modification request:**

Regenerate the prompt reflecting the user's feedback and re-confirm.

## Error Handling

| Situation                        | Response                                     |
| -------------------------------- | -------------------------------------------- |
| Session too short for compaction | Notify that compact is likely unnecessary     |
| Nothing worth preserving         | Suggest a bare `/compact` with no arguments  |
| User cancels                     | Do nothing and exit                          |

## Notes

- `/compact` is a built-in Claude Code command and cannot be invoked programmatically from a skill
- The generated command must be copied and run manually by the user
- Most effective when the session is long and context is running low
