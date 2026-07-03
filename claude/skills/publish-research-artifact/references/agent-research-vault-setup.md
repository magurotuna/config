# Agent Research Vault Setup Notes

Machine-agnostic setup pattern for a Git-backed Obsidian/Basic Memory research vault.

## Recommended roles

- Git repo: source of truth and reviewable history.
- Obsidian: human-facing UI over the Markdown folder.
- Basic Memory: agent-facing semantic search / MCP layer over the same Markdown files.
- Gist: optional share/handoff artifact, not the knowledge base.

## Locating the vault

Do not hardcode the vault's absolute path — it differs per machine. Resolve it with `ghq`:

```bash
VAULT=$(ghq list --full-path magurotuna/agent-research)
```

If it is not yet cloned on this machine:

```bash
ghq get github.com/magurotuna/agent-research
VAULT=$(ghq list --full-path magurotuna/agent-research)
```

## Repo bootstrap (only if the vault does not exist yet)

```bash
ghq create magurotuna/agent-research
VAULT=$(ghq list --full-path magurotuna/agent-research)
git -C "$VAULT" init -b main
gh repo create magurotuna/agent-research \
  --private \
  --description "Markdown research vault for agent-generated Gists and reusable investigation notes" \
  --source "$VAULT" \
  --remote origin
```

Seed files usually include:

```text
README.md
AGENTS.md
CLAUDE.md
templates/research-note.md
templates/topic.md
research/YYYY/*.md
topics/*.md
people/*.md
```

Commit with the machine's configured git identity (do not hardcode a name/email):

```bash
git -C "$VAULT" add .
git -C "$VAULT" commit -m 'docs: initialize agent research vault'
git -C "$VAULT" push -u origin main
```

## Basic Memory local project

Create a local Basic Memory project pointing at the vault and make it default:

```bash
uvx basic-memory project add agent-research "$VAULT" --default
uvx basic-memory project info agent-research
```

Important CLI shape: `--project` belongs to individual subcommands, not the top-level command.

```bash
uvx basic-memory status --project agent-research --json
uvx basic-memory reindex --project agent-research
uvx basic-memory tool search-notes 'Gist Basic Memory Obsidian research vault' \
  --project agent-research --page-size 5
```

If `status --wait` times out with pending changes and says no server is running, run `reindex --project agent-research` directly.

## Basic Memory as an MCP server

To make Basic Memory's tools available to the agent, register it as an MCP server for your
agent runtime. In Claude Code:

```bash
claude mcp add basic-memory -- uvx basic-memory mcp
```

Tools become available in new sessions after restart. (On other runtimes, use that runtime's
MCP registration command; the server command `uvx basic-memory mcp` is the same.)

## Verification checklist

- `gh repo view magurotuna/agent-research --json nameWithOwner,visibility,url,defaultBranchRef`
- `git -C "$VAULT" status --short --branch` is clean after commit/push.
- `uvx basic-memory status --project agent-research --json` reports no pending changes.
- `uvx basic-memory tool search-notes ... --project agent-research` finds seeded notes.
