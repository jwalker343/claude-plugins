---
name: release-plugin
description: Finish a change to an existing plugin in this repo - pick and apply the semver bump, keep the description/README in sync, run checks, and make sure installed machines will pick it up. Use after editing a plugin, or when the user says bump, release, ship, or "why isn't my plugin change showing up".
---

# Release a plugin change

Installed plugins are cached by `version`. A change that doesn't raise the version may
never reach machines that already have the plugin. Do this for any change to a plugin's
behavior.

## 1. Look at what changed

```sh
git diff --stat HEAD -- plugins/<name>
git log --oneline -- plugins/<name>/.claude-plugin/plugin.json | head -3   # last bump
```

If more than one plugin changed, release each one separately.

## 2. Pick the bump

| Change | Bump |
|---|---|
| Bug fix, internal refactor, README or doc wording | patch |
| New command, skill or hook, new optional behavior | minor |
| Removed or renamed component, new required dependency, changed hook output or behavior that the user's dotfiles depend on | major |

Pure doc changes outside the plugin directory need no bump. If it's unclear whether a
change is breaking, ask.

Edit `version` in `plugins/<name>/.claude-plugin/plugin.json`.

## 3. Keep things in sync

- If the plugin's purpose changed, update `description` in **both** `plugin.json` and
  `.claude-plugin/marketplace.json`, and update its `README.md` row.
- If dependencies changed, update the README row.
- If the change touches anything the user's dotfiles rely on (pane options, env vars,
  file paths, command names), say so clearly in the hand-off so the user can update
  `my-dot-files`.

## 4. Verify

```sh
./scripts/check.sh
claude plugin marketplace update <marketplace-name>   # then restart Claude Code to test
```

## 5. Commit (only if asked)

Use one commit per plugin, with a message like `<name>: <what changed> (vX.Y.Z)`.
