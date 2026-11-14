# AGENTS.md

Guidance for AI agents working in this repo. This file describes the repo's shape and
rules. It should not need to change when a plugin is added or edited. Per-plugin details
belong in that plugin's own files and in `README.md`.

## What this repo is

A personal Claude Code **plugin marketplace**. Each subdirectory of `plugins/` is one
self-contained plugin. Machines add the marketplace once and enable only the plugins
they need. Machine-specific settings (permissions, env, model, keybindings, global
`CLAUDE.md`) do **not** live here. They belong in the user's dotfiles repo
(`my-dot-files`), and some plugins work together with config there.

## Layout

```
.claude-plugin/marketplace.json   # the catalog: one entry per plugin, hand-maintained
plugins/<name>/                   # one plugin; directory name == plugin name
  .claude-plugin/plugin.json      # manifest: name, version, description, author
  hooks/ commands/ skills/ agents/ .mcp.json   # whichever components the plugin uses
scripts/check.sh                  # all repo checks; CI runs exactly this
.claude/skills/                   # skills for working *on* this repo (not shipped)
```

## Invariants (enforced by `scripts/check.sh`)

- Each `plugins/<name>/` has a `plugin.json` whose `name` is `<name>`.
- Each plugin has exactly one marketplace entry, with `source: "./plugins/<name>"`.
- The `description` is the same in `plugin.json` and in the marketplace entry.
- Each plugin has a row in the `README.md` plugin table.
- Scripts that hooks call through `${CLAUDE_PLUGIN_ROOT}` exist and are executable.
- Shell passes `shellcheck`, and `claude plugin validate --strict` passes for the
  marketplace and for every plugin.

Run `./scripts/check.sh` before you call work done. If you add a new invariant, enforce
it in that script rather than only writing it down.

## Conventions

- **The marketplace manifest is edited by hand, not generated.** It is small, and the
  check script catches drift. Don't add a generator or a CI step that writes to it.
- **Raise `version` in `plugin.json` whenever a plugin's behavior changes.** Installed
  plugins are cached by version, so machines won't pick up a change made without a
  version bump. Use semver: patch for fixes, minor for new behavior, major for breaking
  changes (renamed commands, removed hooks, new required dependencies).
- **Plugins must be safe to enable anywhere.** Hooks run on every machine where the
  plugin is on, so they must exit 0 quietly when a dependency or context is missing
  (no tmux, no `jq`, not a git repo, and so on). Never block a session over an optional
  feature.
- **Keep hooks fast and dependency-light.** Use POSIX tools plus `jq`. List any
  external dependency in the plugin's README row.
- **Refer to files inside a plugin through `${CLAUDE_PLUGIN_ROOT}`.** Never hard-code
  absolute paths, user names or home directories.
- **One plugin, one concern.** Split unrelated features into separate plugins so each
  machine can choose.

## No secrets

Assume this repo is public and that anything committed is permanent. Removing it in a
later commit doesn't remove it from history.

- Never commit credentials of any kind: API keys, tokens, passwords, private keys,
  certificates, session cookies, `.env` files, or URLs and connection strings that
  contain credentials.
- Plugins that need a secret read it at runtime from an environment variable or the
  user's own config, never from this repo. Document the variable's *name* only. For MCP
  servers, use `${ENV_VAR}` expansion in `.mcp.json` rather than literal values.
- Don't commit personal or machine-specific details: email addresses, internal
  hostnames, IPs, absolute home paths, or account and org IDs. Use placeholders such as
  `<github-user>`. The author name in manifests is fine.
- Examples and test fixtures use obviously fake values, such as `sk-EXAMPLE` or
  `example.com`.
- If a secret is ever committed, stop and tell the user. Treat it as leaked and rotate
  it. Rewriting history is not enough.

## Working here

- Repo-specific workflows are in `.claude/skills/` (`add-plugin`, `release-plugin`).
  For general plugin or skill authoring, use the upstream plugin-dev and skill-creator
  skills. Don't copy them into this repo.
- To test a plugin locally: `claude plugin marketplace update <marketplace-name>`, then
  restart Claude Code. Plugin hooks only load at session start.
- Don't change a plugin's behavior as a side effect of repo-level work. Keep plugin
  changes and infrastructure changes in separate commits.
- Commits are small and imperative ("Add X plugin", "tmux: handle missing jq"), with
  the plugin name as a prefix when the change touches only one plugin.
