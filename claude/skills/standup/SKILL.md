---
name: standup
description: Summarize your recent GitHub activity (PRs, reviews, issues) for standup reporting.
allowed-tools: Bash(gh *), AskUserQuestion
---

# Standup

Summarize your recent GitHub activity to help prepare for standup meetings.

## Execution Flow

### Phase 1: Determine Time Range

Use AskUserQuestion to ask the user:

> What time range should I cover? (default: yesterday)
>
> Examples: "yesterday", "last 3 days", "this week", "2026-03-18..2026-03-20"

If the user accepts the default or says something like "yesterday" / "default", use yesterday's date range.
Otherwise, parse the user's input into a date range.

Compute the `--since` ISO 8601 date string (e.g. `2026-03-21T00:00:00`) accordingly.

### Phase 2: Gather GitHub Activity

Run the following `gh` commands in parallel to collect activity. Replace `SINCE` with the computed date and `USERNAME` with the output of `gh api user -q .login`.

**PRs authored:**
```bash
gh search prs --author=USERNAME --created=">SINCE" --json repository,title,url,state,createdAt,closedAt --limit 50
```

**PRs reviewed:**
```bash
gh search prs --reviewed-by=USERNAME --updated=">SINCE" --json repository,title,url,state,createdAt --limit 50
```

**Issues authored or assigned:**
```bash
gh search issues --author=USERNAME --created=">SINCE" --json repository,title,url,state,createdAt --limit 50
gh search issues --assignee=USERNAME --updated=">SINCE" --json repository,title,url,state,createdAt --limit 50
```

**Review comments (optional, for richer context):**
```bash
gh api "search/issues?q=commenter:USERNAME+updated:>SINCE+type:pr" --jq '.items[] | {title,html_url,repository_url}' 2>/dev/null
```

### Phase 3: Summarize

Deduplicate results and organize into a concise standup summary using this format:

```
## Standup Summary (DATE_RANGE)

### PRs Created
- [repo] title (status) — url

### PRs Reviewed
- [repo] title — url

### Issues
- [repo] title (status) — url

### Other Activity
- (any review comments on PRs not already listed)
```

Omit sections that have no items. Keep descriptions brief — this is for a quick verbal standup.

### Phase 4: Offer Follow-up

After presenting the summary, ask:

> Would you like me to go deeper on any item, or adjust the time range?

## Notes

- Requires `gh` CLI to be authenticated (`gh auth status`)
- All data comes from GitHub's search API via `gh`
- If API rate limits are hit, report the error and suggest narrowing the time range
