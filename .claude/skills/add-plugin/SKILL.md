---
name: add-plugin
description: Scaffold a new plugin in this marketplace repo and register it (plugin dir, plugin.json, marketplace entry, README row), then run the repo checks. Use when the user wants to add, create, or start a new plugin here.
---

# Add a plugin to this marketplace

This covers wiring a plugin into **this repo**. For how to write the plugin's components
(hooks, skills, commands, agents, MCP), use the upstream plugin-dev or skill-creator
skills. Read `AGENTS.md` first for the conventions.

## 1. Pin down the scope

Before you touch any files, settle on:
- **Name**: short kebab-case, named after what it integrates with or does (`tmux`, `git-guard`).
  It must not already exist under `plugins/`.
- **One-sentence description**: what it does, written for someone scanning a list.
  It goes into three places word for word.
- **Components**: hooks, skills, commands, agents and/or MCP. Pick the fewest that do
  the job.
- **Dependencies**: external binaries, and what happens on machines that don't have them.

If the name or scope is unclear, ask. Otherwise go ahead.

## 2. Scaffold

```
plugins/<name>/
  .claude-plugin/plugin.json
  <component dirs as needed>
```

`plugin.json`:
```json
{
  "name": "<name>",
  "version": "0.1.0",
  "description": "<one sentence>",
  "author": { "name": "<copy from an existing plugin.json>" }
}
```

Start at `0.1.0`, and move to `1.0.0` once it has run on a real machine for a while.

For hooks, put the logic in `hooks/<script>.sh` (`chmod +x`) and call it from
`hooks/hooks.json` as `"\"${CLAUDE_PLUGIN_ROOT}/hooks/<script>.sh\""`. The script must
`exit 0` quietly when its dependency or context is missing.

## 3. Register

1. Add `{ "name", "source": "./plugins/<name>", "description" }` to `plugins` in
   `.claude-plugin/marketplace.json`, keeping the list alphabetical.
2. Add a row to the plugin table in `README.md`: `` | `<name>` | <what it does, plus deps> | ``.

## 4. Verify

```sh
./scripts/check.sh
```

Fix every failure. To try the plugin for real, run
`claude plugin marketplace update <marketplace-name>`, then
`claude plugin install <name>@<marketplace-name>`, then restart Claude Code.
Hooks only load at session start.

## 5. Hand off

Report the files you created and what you checked. If the user asks for a commit, make
one with the message `Add <name> plugin`.
