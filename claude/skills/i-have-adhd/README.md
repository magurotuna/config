# i-have-adhd

Vendored from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd)
at commit [`b15d0be58f55b33972ba3e39709e0e5208ef30cb`](https://github.com/ayghri/i-have-adhd/tree/b15d0be58f55b33972ba3e39709e0e5208ef30cb).
`SKILL.md` and `agents/` are unchanged upstream files. The upstream MIT license
is included in `LICENSE`.

## Deployment and use

`home.nix` includes this directory in `verbatimSkills`, so Home Manager deploys
the same copy to `~/.claude/skills/i-have-adhd` and `~/.agents/skills/i-have-adhd`
on WSL, NixOS, and macOS. Apply it with the machine's usual
`home-manager switch --flake .#yusuke@<machine>` command.

The rules also apply automatically in new Codex, Claude Code, OpenCode, and
Cursor CLI sessions. `home.nix` removes the skill's YAML frontmatter and uses
the complete upstream body for every integration:

| Agent | Global integration |
| --- | --- |
| Codex | `~/.codex/AGENTS.md` |
| Claude Code | `~/.claude/output-styles/i-have-adhd.md`, selected by `outputStyle` in `~/.claude/settings.json` |
| OpenCode | `$XDG_CONFIG_HOME/opencode/AGENTS.md` (normally `~/.config/opencode/AGENTS.md`) |
| Cursor CLI (`cursor-agent` / `agent`) | `~/.cursor/plugins/local/i-have-adhd-always/rules/i-have-adhd.mdc` with `alwaysApply: true` |

Claude's output style retains its built-in coding instructions and replaces
the previous `Explanatory` style. Cursor's local plugin and rule are installed
as regular files on every Home Manager switch because its plugin loader
rejects symlinks that resolve outside the plugin directory. The plugin's MIT
license is copied alongside them. The other integrations use Nix store links.

Start a new agent session after applying changes. Say `stop adhd mode` or
`normal mode` to turn the rules off for that session; a new session enables
them again. Project-specific settings and explicit instructions can override
these personal defaults.

The standalone skill still supports `/i-have-adhd` in Claude Code and
`$i-have-adhd` in Codex, but invoking it is unnecessary for the automatic
integrations. Its upstream manual-invocation metadata is preserved. The
upstream plugin's optional always-on hook is not needed.

The integration paths and formats follow the
[Codex instructions guide](https://developers.openai.com/codex/guides/agents-md),
[Claude output style guide](https://code.claude.com/docs/en/output-styles),
[OpenCode rules guide](https://opencode.ai/docs/rules/), and
[Cursor plugin guide](https://cursor.com/docs/plugins#test-plugins-locally).

## Updating

Choose an upstream commit and replace `SKILL.md` and `agents/` with its
`skills/i-have-adhd/` contents. Refresh `LICENSE` from the same commit, update
the commit link above, and review the diff. Stage any new files so the flake
can see them, then apply Home Manager. `nix flake update` does not update this
vendored copy.

## Disabling automatic loading

Remove the global instruction files, Claude output style and its settings
selection, and Cursor activation from `home.nix`, then apply Home Manager.
Also delete `~/.cursor/plugins/local/i-have-adhd-always`: its regular-file copy
is not removed automatically by Home Manager. The standalone skill can remain
installed for manual use.
