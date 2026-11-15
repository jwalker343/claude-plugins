#!/bin/sh
# notify.sh — single dispatcher for all claude-wsl-notify hooks.
# Usage: notify.sh <role>   with the hook JSON on stdin.
# Roles: attention | toast | done | done-toast | flash-start | clear
# Sync roles print exactly one JSON line (terminalSequence) or nothing.
# Always exits 0 so a failure here never blocks Claude.

handle_attention() {
    # State lets `done` know not to clobber an active alert later.
    printf 'attention' > "$(cwn_state_file "$SID")" 2>/dev/null || true

    seq="$(cwn_jseq_title "$CWN_ATTENTION_LABEL")$(cwn_jseq_bel)"
    # OSC 9 raises a native Windows Terminal toast. Suppress it when the richer
    # PowerShell toast is enabled, so the user gets one toast, not two.
    if [ "$CWN_ENABLE_OSC9_TOAST" = "1" ] && [ "$CWN_ENABLE_POWERSHELL_TOAST" != "1" ]; then
        seq="$seq$(cwn_jseq_osc9 "${MSG:-Claude needs your attention}")"
    fi
    cwn_emit "$seq"
}

# Launch the PowerShell toast with the given body. Shared by the urgent and the
# soft "done" toasts so the wslpath/exec-check logic lives in one place. Runs
# from an async hook, so blocking here is fine and keeps PowerShell in the
# foreground (no orphaned child to be reaped when the hook exits).
cwn_run_ps_toast() {
    [ -x "$CWN_POWERSHELL_PATH" ] || { cwn_log "toast: powershell not found at $CWN_POWERSHELL_PATH"; return 0; }

    toast_script="$DIR/../toast/toast.ps1"
    if command -v wslpath >/dev/null 2>&1; then
        win_path="$(wslpath -w "$toast_script" 2>/dev/null || printf '%s' "$toast_script")"
    else
        win_path="$toast_script"
    fi
    cwn_log "toast: launching $win_path"
    "$CWN_POWERSHELL_PATH" -NoProfile -ExecutionPolicy Bypass -File "$win_path" \
        -Title "Claude Code" -Body "$1" >>"$CWN_LOG" 2>&1 || true
}

handle_toast() {
    [ "$CWN_ENABLE_POWERSHELL_TOAST" != "1" ] && return 0
    cwn_run_ps_toast "${MSG:-Claude needs your attention}"
}

handle_done() {
    # Soft "your turn" signal: bell and/or title, no state file, no flasher.
    seq=""
    [ "$CWN_ENABLE_DONE_TITLE" = "1" ] && seq="$seq$(cwn_jseq_title "$CWN_DONE_LABEL")"
    [ "$CWN_ENABLE_DONE_BELL" = "1" ]  && seq="$seq$(cwn_jseq_bel)"
    # OSC 9 native toast only when the richer PowerShell toast is off (avoid two).
    if [ "$CWN_ENABLE_DONE_TOAST" = "1" ] && [ "$CWN_ENABLE_OSC9_TOAST" = "1" ] && [ "$CWN_ENABLE_POWERSHELL_TOAST" != "1" ]; then
        seq="$seq$(cwn_jseq_osc9 "$CWN_DONE_TOAST_BODY")"
    fi
    [ -n "$seq" ] && cwn_emit "$seq"
}

handle_done_toast() {
    [ "$CWN_ENABLE_DONE_TOAST" != "1" ] && return 0
    [ "$CWN_ENABLE_POWERSHELL_TOAST" != "1" ] && return 0
    cwn_run_ps_toast "$CWN_DONE_TOAST_BODY"
}

handle_clear() {
    # The user responded: drop the attention state (the flasher's loop watches
    # it) and kill any live flasher outright so it stops within a frame instead
    # of after up to one flash interval. The flasher's EXIT trap restores the
    # resting title and removes its pid file.
    rm -f "$(cwn_state_file "$SID")" 2>/dev/null || true
    pid_file="$(cwn_pid_file "$SID")"
    if [ -f "$pid_file" ]; then
        fp=$(cat "$pid_file" 2>/dev/null)
        [ -n "$fp" ] && kill "$fp" 2>/dev/null || true
    fi
}

handle_flash_start() {
    [ "$CWN_ENABLE_FLASHER" != "1" ] && return 0
    # Resolve the pts here, while our ancestry still reaches claude; the detached
    # flasher loses that ancestry, so we hand it the device as an argument.
    pts="$(cwn_find_pts)"
    if [ -z "$pts" ] || [ ! -w "$pts" ]; then
        cwn_log "flash-start: no writable pts found"
        return 0
    fi
    resting="$(cwn_resting_title "$CWD" "$SID")"
    cwn_log "flash-start: sid=$SID pts=$pts"
    # setsid → new session, so the flasher survives this short-lived async hook.
    setsid sh "$DIR/flash-title.sh" "$SID" "$pts" "$resting" </dev/null >>"$CWN_LOG" 2>&1 &
}

main() {
    DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || return 0
    . "$DIR/lib.sh" || return 0

    CWN_INPUT=$(cat 2>/dev/null || true)

    EVENT=$(cwn_json_get hook_event_name)
    SID=$(cwn_json_get session_id)
    CWD=$(cwn_json_get cwd)
    MSG=$(cwn_json_get message)
    : "${CWD:=$PWD}"

    cwn_log "role=$1 event=$EVENT sid=$SID cwd=$CWD"

    # `clear` runs on every PostToolUse, so keep it off the config (jq) path —
    # it only needs SID. The other roles load config on demand.
    case "$1" in
        attention)   cwn_load_config; handle_attention ;;
        toast)       cwn_load_config; handle_toast ;;
        done)        cwn_load_config; handle_done ;;
        done-toast)  cwn_load_config; handle_done_toast ;;
        flash-start) cwn_load_config; handle_flash_start ;;
        clear)       handle_clear ;;
        *)           cwn_log "unknown role: $1" ;;
    esac
}

main "$@" || true
exit 0
