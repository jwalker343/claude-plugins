# claude-plugins

Personal Claude Code plugin marketplace (`my-plugins`) — dotfiles for Claude features.
Each machine installs only the plugins it needs.

## Plugins

| Plugin | What it does |
|--------|--------------|
| `adhd-style` | Output style **Pretend I Have ADHD** (pick it in `/config` → Output style, or set `"outputStyle": "adhd-style:Pretend I Have ADHD"` in settings) that shapes replies for an ADHD reader: next action first, numbered steps, state restated each turn, tangents deferred, concrete time estimates, no preamble or closers. Keeps Claude Code's coding instructions. Adapted from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT). No dependencies. |
| `discuss` | Skill (`/discuss <topic>`, or auto-started when you ask to talk an approach through before building) for talking through a feature or direction before building: options, pros/cons, best practices, failure modes and blast radius, with a recommendation. Read-only (Read/Grep/Glob, WebSearch/WebFetch); stays in discussion across turns and writes a self-contained hand-off prompt for a fresh implementation agent when asked. Pinned to Opus at high effort. |
| `optimize-prompt` | User-invoked skill (`/optimize-prompt <rough prompt>`) that rewrites a prompt into a structured, codebase-grounded Claude Code prompt and lists any session commands to run first. Read-only tools; pinned to Opus at high effort. |
| `tmux` | `SessionStart` hook that sets the pane option `@claude_session` to the session id. The tmux binding in `my-dot-files` (Alt+Shift+F / prefix+f) uses it to run `claude --resume <id> --fork-session` in a split. Needs `jq` and `tmux`. |
| `wsl-notify` | Alerts in Windows Terminal (WSL2) when Claude is blocked on you (permission prompt, AskUserQuestion, ExitPlanMode): title change, bell, Windows toast, optional title flasher. A softer toast + bell when a turn finishes. Config: `~/.claude/claude-wsl-notify/config.json` (see [its README](plugins/wsl-notify/README.md)). POSIX `sh`; `jq` optional; `powershell.exe` optional for the richer toast. Off WSL the toast is skipped and only title/bell escapes are emitted. |

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
