# wsl-notify

A Claude Code plugin for WSL2 under Windows Terminal that alerts you when Claude needs your input.

## What it does

- **Urgent attention signal**: When Claude is *blocked on you* (permission prompt, AskUserQuestion, or ExitPlanMode), changes the title to an attention label, rings the terminal bell (Windows Terminal shows a bell indicator on the tab), raises a Windows toast, and flashes the title ~1/second until you respond. It does not otherwise manage the tab title (Claude Code owns the idle/done title), so the attention label persists until Claude overwrites it.
- **Soft "done / your turn" signal**: When Claude finishes a turn and is simply waiting for your next prompt (`idle_prompt`), gives a quieter, distinct alert — a toast with its own text ("Task complete — your turn") and a bell, but **no** title flashing. An optional distinct title label (`✓ Claude done`) is available but off by default. This keeps turn-completion from looking like an urgent block.
- **Tunable**: The urgent toast/flasher and the soft done toast/bell/title are each on/off individually (see Configuration).

## Why this design

Claude Code v2.1.139+ runs hooks without a controlling terminal — hooks cannot write escape sequences directly to the terminal. Instead, hooks print a JSON object `{"terminalSequence":"..."}` on stdout and Claude Code emits the escape on the hook's behalf. Allowed escapes are limited to OSC 0/1/2 (titles), OSC 9 (Windows Terminal toast), and BEL. The attention signal uses a title change + bell + toast (all supported, instant, race-free). The flasher writes directly to the session's pseudo-terminal device, outside that JSON path (see Caveats).

## Requirements

- Claude Code v2.1.141 or newer (requires the `terminalSequence` hook output field).
- WSL2 + Windows Terminal.
- For the optional PowerShell toast: Windows 10/11 with `powershell.exe` (Windows PowerShell 5.1 is fine; no external modules needed).
- `jq` is used if present but is NOT required — scripts have a pure-shell fallback.

## Project layout

```
plugins/wsl-notify/
  .claude-plugin/plugin.json        # plugin "wsl-notify"
  hooks/hooks.json                  # hook wiring
  scripts/
    notify.sh                       # dispatcher (all hooks call this)
    lib.sh                          # shared functions
    flash-title.sh                  # title flasher
    stop-flash.sh                   # manually stop the flasher
    config.default.json             # config template
  toast/toast.ps1                   # PowerShell toast (optional)
```

## Install

Part of the `my-plugins` marketplace (see the repo README):

```bash
claude plugin install wsl-notify@my-plugins
```

Restart Claude Code to activate. For a quick dev loop without reinstalling:
`claude --plugin-dir <repo>/plugins/wsl-notify`, then `/reload-plugins` after edits.

User config lives outside the plugin (see Configuration below) so it survives reinstalls.

## Configuration

Config is a JSON object at `~/.claude/claude-wsl-notify/config.json`, sitting
alongside other Claude plugin settings (e.g. `~/.claude/claude-powerline.json`).
Every key is optional — omitted keys keep their built-in default. Copy the
template to get started:

```bash
mkdir -p ~/.claude/claude-wsl-notify
cp <repo>/plugins/wsl-notify/scripts/config.default.json ~/.claude/claude-wsl-notify/config.json
```

Edit `~/.claude/claude-wsl-notify/config.json` with your preferences. Booleans
are JSON `true`/`false`; numbers are bare; strings are quoted.

| Key | Default | Meaning |
|-----|---------|---------|
| `restingTitleFormat` | `"{dir}"` | Non-alert title the flasher restores/alternates against; `{dir}`=cwd basename, `{sid}`=first 4 chars of session id. Only used when the flasher is enabled. |
| `attentionLabel` | `"(!) Claude needs you"` | Title shown when Claude needs input. |
| `enableOsc9Toast` | `true` | Raise a native Windows Terminal toast on attention. |
| `enablePowershellToast` | `true` | Use the richer PowerShell toast instead of OSC 9 (auto-suppresses OSC 9 to avoid double toast). Slower (PowerShell cold start ~0.5–1s); runs in the background. Set to `false` to fall back to the OSC 9 toast. |
| `enableFlasher` | `true` | Enable the title flasher (urgent alert only). Set to `false` to disable. |
| `flashInterval` | `1` | Seconds between title flips. |
| `flashMaxSeconds` | `60` | Auto-stop the flasher after this long. |
| `enableDoneToast` | `true` | Raise a toast on the soft "done / your turn" signal (`idle_prompt`). Uses PowerShell or OSC 9 per the toast settings above. |
| `enableDoneBell` | `true` | Ring the bell on the soft "done" signal. |
| `enableDoneTitle` | `false` | Also set the tab title to `doneLabel` on the soft "done" signal. Off by default. |
| `doneLabel` | `"✓ Claude done"` | Title shown on the soft "done" signal when `enableDoneTitle` is on. |
| `doneToastBody` | `"Task complete — your turn"` | Toast body for the soft "done" signal. |
| `powershellPath` | `"/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"` | Path to PowerShell executable. |
| `logPath` | `"/tmp/claude-wsl-notify.log"` | Log file location. |

> Reading the JSON config requires `jq`. If `jq` is unavailable the plugin falls
> back to built-in defaults (it never blocks). Hook handling itself does not need `jq`.

## Event handlers

Two tiers: a loud alert when Claude is blocked on you, and a soft alert when a turn simply ends. Outside these, the plugin does not touch the title.

| Event | Action |
|-------|--------|
| Notification (permission_prompt) | **Urgent**: attention title + bell + toast + optional flasher + optional PowerShell toast |
| PreToolUse (AskUserQuestion, ExitPlanMode) | **Urgent**: same as above |
| Notification (idle_prompt) | **Soft**: done toast + bell (+ optional done title); no flasher |

## Manual testing

Navigate to the scripts directory and pipe simulated hook payloads to the dispatcher:

```bash
cd <repo>/plugins/wsl-notify/scripts
```

**Attention** — expect a terminalSequence with the attention label, a bell, and an OSC 9 toast:

```bash
echo '{"hook_event_name":"Notification","session_id":"test-1234","cwd":"/tmp/example-project","message":"permission needed"}' | sh notify.sh attention
```

**Optional PowerShell toast** — if enabled, should pop a Windows notification. Note the env var goes on the `notify.sh` side of the pipe (it must reach that process, not `echo`):

```bash
echo '{"hook_event_name":"Notification","session_id":"test-1234","cwd":"/tmp/example-project","message":"permission needed"}' | CWN_ENABLE_POWERSHELL_TOAST=1 sh notify.sh toast
```

**Soft "done" signal** — expect a terminalSequence with a bell and (with the PowerShell toast disabled) an OSC 9 "Task complete — your turn" toast, but no title by default:

```bash
echo '{"hook_event_name":"Notification","session_id":"test-1234","cwd":"/tmp/example-project"}' | CWN_ENABLE_POWERSHELL_TOAST=0 sh notify.sh done
```

**Soft "done" PowerShell toast** — if enabled, should pop a Windows notification with the body "Task complete — your turn":

```bash
echo '{"hook_event_name":"Notification","session_id":"test-1234","cwd":"/tmp/example-project"}' | CWN_ENABLE_POWERSHELL_TOAST=1 sh notify.sh done-toast
```

**Optional flasher** — in a real Windows Terminal tab. The flasher only runs while the session's attention state is armed, so set it first; use this tab's own pts (`tty`):

```bash
printf attention > /tmp/claude-wsl-notify-test-1234.state
sh flash-title.sh test-1234 "$(tty)" "resting-title-here"
```

Stop it with (also clears the state file and restores the title):

```bash
sh stop-flash.sh test-1234
```

## Uninstall

```bash
claude plugin uninstall wsl-notify@my-plugins
```

## Caveats / tips

- **Windows Terminal enhancement**: In WT settings, set the profile's `bellStyle` to include `window` and/or `taskbar` so the bell on attention also flashes the window and taskbar, not just the tab indicator.
- **Flasher**: The title flasher (`enableFlasher`, on by default) writes escape sequences directly to the session's pseudo-terminal, which Claude Code's renderer also writes to. During redraws this can cause brief title "thrash" or rarely a transient glitch. It is hard-capped (`flashMaxSeconds`), single-writer (one flasher per session via a pid file), and self-restores the resting title when it stops. Set `enableFlasher` to `false` to disable it.
- **Minimal dependencies**: Pure POSIX shell plus optional PowerShell for the toast. `jq` is required only to read the JSON config; without it the plugin runs on built-in defaults. Hook payload parsing has a pure-shell fallback.
- **Silent failure**: Scripts always exit 0 so a problem never blocks Claude Code. Debug output goes to the log file (CWN_LOG).
- **Independent plugin**: This plugin does not modify your existing hooks or the claude-notifications-go plugin; it is fully independent.
