#!/bin/sh
# lib.sh — shared functions for claude-wsl-notify.
# Sourced by the hook scripts; defines functions only, no top-level logic.
#
# Two distinct escape-emission paths, deliberately kept separate:
#   * Hook stdout  -> JSON {"terminalSequence":"]0;..."}, built with
#     LITERAL \uXXXX text (never raw control bytes). Claude Code emits it for us;
#     hooks have no controlling terminal so we cannot write the tty directly.
#   * Flasher/stop -> RAW ESC/BEL bytes written straight to the session's pts
#     device (cwn_raw_title), since that path does talk to the terminal.

# --- jq discovery (absolute-path probe; hook PATH is minimal) ----------------
CWN_JQ=""
CWN_JQ_SEARCHED=""
cwn_find_jq() {
    if [ -n "$CWN_JQ_SEARCHED" ]; then printf '%s' "$CWN_JQ"; return; fi
    CWN_JQ_SEARCHED=1
    for _c in /home/linuxbrew/.linuxbrew/bin/jq /usr/bin/jq /usr/local/bin/jq /opt/homebrew/bin/jq; do
        if [ -x "$_c" ]; then CWN_JQ="$_c"; printf '%s' "$CWN_JQ"; return; fi
    done
    if command -v jq >/dev/null 2>&1; then CWN_JQ=$(command -v jq); fi
    printf '%s' "$CWN_JQ"
}

# --- input parsing -----------------------------------------------------------
# Read a top-level string field from $CWN_INPUT (captured stdin). jq when
# available; a narrow grep/sed fallback otherwise (best-effort for cwd/message).
cwn_json_get() {
    _field="$1"
    _jq=$(cwn_find_jq)
    if [ -n "$_jq" ]; then
        printf '%s' "$CWN_INPUT" | "$_jq" -r --arg f "$_field" '.[$f] // empty' 2>/dev/null || true
    else
        printf '%s' "$CWN_INPUT" \
            | grep -o "\"$_field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
            | sed 's/^"[^"]*"[[:space:]]*:[[:space:]]*"\(.*\)"$/\1/' \
            | head -n1 || true
    fi
}

# --- text helpers ------------------------------------------------------------
# Escape a string for inclusion inside a JSON string: strip control bytes
# (so a malicious message cannot inject its own escapes), then escape \ and ".
cwn_json_escape_text() {
    printf '%s' "$1" | tr -d '[:cntrl:]' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Replace every literal occurrence of $2 in $1 with $3 (pure sh; no sed, so the
# replacement may safely contain &, /, etc.).
cwn_gsub() {
    _hay="$1"; _need="$2"; _rep="$3"; _out=""
    while :; do
        case "$_hay" in
            *"$_need"*)
                _out="$_out${_hay%%"$_need"*}$_rep"
                _hay="${_hay#*"$_need"}"
                ;;
            *) break ;;
        esac
    done
    printf '%s' "$_out$_hay"
}

# First 4 chars of a session id (for disambiguating multiple windows).
cwn_sid_short() {
    _s="$1"
    printf '%s' "$_s" | cut -c1-4
}

# Apply {dir}/{sid} substitutions to a title format string.
cwn_format_title() {
    _t=$(cwn_gsub "$1" '{dir}' "$2")
    cwn_gsub "$_t" '{sid}' "$3"
}

cwn_resting_title() {
    cwn_format_title "$CWN_RESTING_TITLE_FORMAT" "${1##*/}" "$(cwn_sid_short "$2")"
}

# --- JSON terminalSequence fragments (literal \uXXXX, never raw bytes) --------
# \\ in the printf format yields one backslash, then literal u001b/u0007; dash's
# printf does not interpret \u, and the leading \\ prevents any \u escape anyway.
cwn_jseq_title() { printf '\\u001b]0;%s\\u0007' "$(cwn_json_escape_text "$1")"; }
cwn_jseq_osc9()  { printf '\\u001b]9;%s\\u0007' "$(cwn_json_escape_text "$1")"; }
cwn_jseq_bel()   { printf '\\u0007'; }

# Wrap pre-built, already-JSON-safe fragments into the output object.
cwn_emit() { printf '{"terminalSequence":"%s"}\n' "$1"; }

# --- raw escape for direct pts writes (flasher / stop-flash) -----------------
cwn_raw_title() { printf '\033]0;%s\007' "$1"; }

# --- config ------------------------------------------------------------------
# User config is a JSON object at ~/.claude/claude-wsl-notify/config.json,
# alongside other Claude plugin settings (e.g. claude-powerline.json). It
# survives plugin reinstalls (which re-copy the cache dir).

# Read one top-level key from the config file. Uses has() rather than `// empty`
# so a key set to JSON `false` is still returned (// treats false as empty).
# Prints nothing when the key is absent or the file/jq is unavailable.
cwn_cfg_get() {
    [ -f "$CWN_CONFIG_JSON" ] || return 0
    _jq=$(cwn_find_jq)
    [ -n "$_jq" ] || return 0
    "$_jq" -r --arg k "$1" 'if has($k) then .[$k] else empty end' "$CWN_CONFIG_JSON" 2>/dev/null || true
}

# Map a JSON value to a 1/0 flag: true -> 1, anything else (false/absent) -> 0.
cwn_cfg_bool() {
    [ "$1" = "true" ] && printf '1' || printf '0'
}

cwn_load_config() {
    # NB: defaults containing '}' (the {dir}/{sid} placeholders) cannot use the
    # ${VAR:=default} form — the '}' would close the expansion early. Use an
    # explicit set-test (${VAR+x} is 'x' iff VAR is set, even when empty).
    [ -n "${CWN_RESTING_TITLE_FORMAT+x}" ] || CWN_RESTING_TITLE_FORMAT='{dir}'
    : "${CWN_ATTENTION_LABEL:=(!) Claude needs you}"
    : "${CWN_ENABLE_OSC9_TOAST:=1}"
    : "${CWN_ENABLE_POWERSHELL_TOAST:=1}"
    : "${CWN_ENABLE_FLASHER:=1}"
    : "${CWN_FLASH_INTERVAL:=1}"
    : "${CWN_FLASH_MAX_SECONDS:=60}"
    # Soft "done / your turn" alert (idle_prompt): toast + bell on, title off.
    : "${CWN_ENABLE_DONE_TOAST:=1}"
    : "${CWN_ENABLE_DONE_BELL:=1}"
    : "${CWN_ENABLE_DONE_TITLE:=0}"
    : "${CWN_DONE_LABEL:=✓ Claude done}"
    : "${CWN_DONE_TOAST_BODY:=Task complete — your turn}"
    : "${CWN_POWERSHELL_PATH:=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe}"
    : "${CWN_LOG:=/tmp/claude-wsl-notify.log}"

    CWN_CONFIG_JSON="$HOME/.claude/claude-wsl-notify/config.json"
    if [ -f "$CWN_CONFIG_JSON" ]; then
        if [ -z "$(cwn_find_jq)" ]; then
            cwn_log "config: $CWN_CONFIG_JSON present but jq not found; using defaults"
        else
            # Strings: override only when the key is present (empty = absent).
            _v=$(cwn_cfg_get restingTitleFormat); [ -n "$_v" ] && CWN_RESTING_TITLE_FORMAT="$_v"
            _v=$(cwn_cfg_get attentionLabel);     [ -n "$_v" ] && CWN_ATTENTION_LABEL="$_v"
            _v=$(cwn_cfg_get doneLabel);          [ -n "$_v" ] && CWN_DONE_LABEL="$_v"
            _v=$(cwn_cfg_get doneToastBody);      [ -n "$_v" ] && CWN_DONE_TOAST_BODY="$_v"
            _v=$(cwn_cfg_get powershellPath);     [ -n "$_v" ] && CWN_POWERSHELL_PATH="$_v"
            _v=$(cwn_cfg_get logPath);            [ -n "$_v" ] && CWN_LOG="$_v"
            _v=$(cwn_cfg_get flashInterval);      [ -n "$_v" ] && CWN_FLASH_INTERVAL="$_v"
            _v=$(cwn_cfg_get flashMaxSeconds);    [ -n "$_v" ] && CWN_FLASH_MAX_SECONDS="$_v"
            # Booleans: override only when present (false must still apply).
            _v=$(cwn_cfg_get enableOsc9Toast);       [ -n "$_v" ] && CWN_ENABLE_OSC9_TOAST=$(cwn_cfg_bool "$_v")
            _v=$(cwn_cfg_get enablePowershellToast); [ -n "$_v" ] && CWN_ENABLE_POWERSHELL_TOAST=$(cwn_cfg_bool "$_v")
            _v=$(cwn_cfg_get enableFlasher);         [ -n "$_v" ] && CWN_ENABLE_FLASHER=$(cwn_cfg_bool "$_v")
            _v=$(cwn_cfg_get enableDoneToast);       [ -n "$_v" ] && CWN_ENABLE_DONE_TOAST=$(cwn_cfg_bool "$_v")
            _v=$(cwn_cfg_get enableDoneBell);        [ -n "$_v" ] && CWN_ENABLE_DONE_BELL=$(cwn_cfg_bool "$_v")
            _v=$(cwn_cfg_get enableDoneTitle);       [ -n "$_v" ] && CWN_ENABLE_DONE_TITLE=$(cwn_cfg_bool "$_v")
        fi
    fi

    # Flasher timing must be integer seconds (shell arithmetic is integer-only).
    case "$CWN_FLASH_INTERVAL" in *[!0-9]*|'') CWN_FLASH_INTERVAL=1 ;; esac
    case "$CWN_FLASH_MAX_SECONDS" in *[!0-9]*|'') CWN_FLASH_MAX_SECONDS=60 ;; esac
}

# --- session / process helpers -----------------------------------------------
# Find this session's terminal by walking our own ancestry to the first ancestor
# with a pts (that is the claude UI). Never search for "a claude process" — there
# may be several concurrent sessions.
cwn_find_pts() {
    _pid=$$
    _depth=0
    while [ "$_depth" -lt 10 ]; do
        [ -z "$_pid" ] && break
        case "$_pid" in *[!0-9]*) break ;; esac
        [ "$_pid" -le 1 ] && break
        _tty=$(ps -o tty= -p "$_pid" 2>/dev/null | tr -d ' ')
        case "$_tty" in pts/*) printf '/dev/%s' "$_tty"; return ;; esac
        _pid=$(ps -o ppid= -p "$_pid" 2>/dev/null | tr -d ' ')
        _depth=$((_depth + 1))
    done
}

cwn_safe_sid() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }
cwn_state_file() { printf '/tmp/claude-wsl-notify-%s.state' "$(cwn_safe_sid "$1")"; }
cwn_pid_file()   { printf '/tmp/claude-wsl-notify-flash-%s.pid' "$(cwn_safe_sid "$1")"; }

cwn_log() { printf '%s\n' "$1" >> "${CWN_LOG:-/tmp/claude-wsl-notify.log}" 2>/dev/null || true; }
