# claude-plugins

Personal Claude Code plugin marketplace (`my-plugins`) — dotfiles for Claude features.
Each machine installs only the plugins it needs.

## Plugins

| Plugin | What it does |
|--------|--------------|
| `tmux` | `SessionStart` hook that sets the pane option `@claude_session` to the session id. The tmux binding in `my-dot-files` (Alt+Shift+F / prefix+f) uses it to run `claude --resume <id> --fork-session` in a split. Needs `jq` and `tmux`. |

## Install

From inside Claude Code:

```
/plugin marketplace add jwalker343/claude-plugins
/plugin install tmux@my-plugins
```

Or from the shell:

```sh
claude plugin marketplace add jwalker343/claude-plugins
claude plugin install tmux@my-plugins
```

Restart Claude Code after installing so the hooks load. To pick up new pushes, run
`claude plugin marketplace update my-plugins`.

### Automating via dotfiles

Add to the base `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "my-plugins": {
      "source": { "source": "github", "repo": "jwalker343/claude-plugins" }
    }
  },
  "enabledPlugins": {
    "tmux@my-plugins": true
  }
}
```

On a machine where you edit plugins, use a local checkout instead so changes apply
without pushing: `{ "source": "directory", "path": "/absolute/path/to/claude-plugins" }`.

## What can't go here

Plugins can ship commands, skills, agents, hooks, MCP and LSP servers. Settings
(permissions, env, model), keybindings and `CLAUDE.md` stay in `my-dot-files`.
Plugin hooks merge with hooks in `settings.json`, so per-machine hooks keep working.

## Develop

```sh
./scripts/check.sh                            # all checks (CI runs the same script)
claude plugin marketplace update my-plugins   # pick up local changes, then restart Claude Code
```

Bump `version` in a plugin's `plugin.json` whenever its behavior changes — installed
plugins are cached by version. Conventions for contributors (human or agent) live in
[`AGENTS.md`](AGENTS.md).
