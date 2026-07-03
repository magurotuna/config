---
name: publish-research-artifact
description: Publish agent research as a durable Markdown vault entry, optionally with a GitHub Gist share artifact.
allowed-tools: Bash(git *), Bash(gh *), Bash(ghq *), Bash(uvx *), Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Publish Research Artifact

Use when the user asks an agent to research something and wants the result preserved for later recall, especially when the output may be uploaded to a Gist.

## Research vault

The research vault is the Git repository `magurotuna/agent-research`. Do not hardcode its
absolute path — it differs per machine. Locate it at runtime:

```bash
VAULT=$(ghq list --full-path magurotuna/agent-research)
```

If that returns nothing, the repo is not cloned on this machine — clone it into the
standard location and use that path:

```bash
ghq get github.com/magurotuna/agent-research
VAULT=$(ghq list --full-path magurotuna/agent-research)
```

The vault is both a Git repository and an Obsidian-compatible Markdown vault. All paths in
this skill (e.g. `research/...`, `topics/...`, `templates/...`) are relative to `$VAULT`.

## Key principle

Gist is optional and is only the share/handoff artifact. The searchable knowledge base is the Markdown vault.

- Create a Gist when the user asks for a shareable URL, a public/private handoff artifact, or a long-form report suitable for external reading.
- Do not create a Gist for internal-only recall unless asked.
- When a Gist is created, always create or update a vault note that links to it.

## Workflow

1. Finish the research with source-grounded findings.
2. Decide whether a Gist is needed:
   - Yes: publish the long-form artifact to Gist, preferably private unless public is requested.
   - If the user already created/asked for Gists earlier in the session, do **not** recreate them; index the existing Gist URL(s) in the vault note and `source_urls`.
   - No: use `gist_url: null` in the vault note.
3. Create a note under:

   ```text
   $VAULT/research/YYYY/YYYY-MM-DD-short-kebab-title.md
   ```

4. Copy the structure from `$VAULT/templates/research-note.md`.
5. Fill required frontmatter:
   - `title`
   - `date`
   - `type: research`
   - `status`
   - `gist_url`
   - `tags`
   - `projects`
   - `agents`
   - `source_urls`
6. Include a concise `## TL;DR` section.
7. Add `[[wikilinks]]` to relevant topic notes.
8. Append the new note to each relevant `$VAULT/topics/*.md` page under `## Related research`.
   - If a relevant topic page does not exist, create it from `$VAULT/templates/topic.md` rather than skipping the wikilink.
   - Always update general hub topics such as `topics/agent-research.md` and `topics/gist.md` when they are relevant to the artifact.
9. Run checks (from inside `$VAULT`):
   - `git status --short --branch`
   - `git diff --stat`
   - `git diff`
   - For new/untracked notes, do not rely on plain `git diff`/`git diff --stat` because they omit untracked files. Inspect the new file directly and/or use `git diff --no-index -- /dev/null <new-note.md>` before claiming the artifact was reviewed.
   - if Basic Memory is configured: `uvx basic-memory status --project agent-research --json`
   - if Basic Memory reports pending changes or `--wait` times out, run `uvx basic-memory reindex --project agent-research`, then check status again.
10. Commit only scoped changes when the user asked for setup/persistence or commit is clearly desired. Use the machine's configured git identity — do not hardcode a name or email.

## Gist creation commands

Prefer `gh gist create` with an explicit filename and description. Use private by default.

```bash
gh gist create report.md --desc "Research: <title>" --filename "<YYYY-MM-DD-title>.md"
```

Use `--public` only if the user explicitly requests public sharing.

## Note conventions

- Keep Markdown human-readable.
- Use Japanese for Japanese-facing notes unless the artifact is explicitly English.
- Use bullets over long prose.
- Avoid tables for Discord summaries.
- Never store secrets, tokens, customer data, or credentials.
- Prefer append-only dated corrections over rewriting old conclusions.

## Basic Memory

If Basic Memory MCP/tools are available, search the vault before claiming there is no prior related research. Basic Memory is an index/API layer; Markdown files remain the source of truth.

## References

- `references/agent-research-vault-setup.md` — machine-agnostic bootstrap commands for a Git-backed Obsidian/Basic Memory research vault, including Basic Memory CLI setup.

## Verification checklist

- [ ] Vault note exists and has required frontmatter.
- [ ] `gist_url` is present or explicitly `null`.
- [ ] Related topic pages are linked.
- [ ] `git diff` was inspected.
- [ ] No secrets were written.
- [ ] If pushed, GitHub repo URL and commit are verified.
