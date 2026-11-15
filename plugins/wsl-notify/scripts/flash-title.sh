#!/bin/sh
# flash-title.sh — attention flasher.
# Alternates the terminal title ~1/sec by writing OSC escapes directly to the
# session's pts. It writes to the same pts Claude's renderer owns, so it can
# briefly contend during redraws. Launched detached from notify.sh's
# flash-start role.
# Args: SID  PTS(device, e.g. /dev/pts/8)  RESTING_TITLE
#
# State is intentionally script-global (not function-local): the EXIT trap fires
# at top level, after main() returns, where function locals are out of scope.

SID="$1"
PTS="$2"
RESTING_TITLE="$3"

cleanup_flash() {
    [ -n "$PTS" ] && [ -w "$PTS" ] && cwn_raw_title "$RESTING_TITLE" > "$PTS" 2>/dev/null || true
    [ -n "$PID_FILE" ] && rm -f "$PID_FILE" 2>/dev/null || true
}

main() {
    DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || return 0
    . "$DIR/lib.sh" || return 0
    cwn_load_config

    PID_FILE=$(cwn_pid_file "$SID")
    STATE_FILE=$(cwn_state_file "$SID")

    # Single-writer guard: bail if a live flasher already owns this session.
    if [ -f "$PID_FILE" ]; then
        _old=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$_old" ] && kill -0 "$_old" 2>/dev/null; then
            cwn_log "flash: already running for $SID (pid $_old)"
            return 0
        fi
    fi
    printf '%s' "$$" > "$PID_FILE" 2>/dev/null || return 0
    trap cleanup_flash EXIT INT TERM

    cwn_log "flash: start sid=$SID pts=$PTS"
    counter=0
    while [ "$counter" -lt "$CWN_FLASH_MAX_SECONDS" ]; do
        [ -f "$STATE_FILE" ] || break
        [ "$(cat "$STATE_FILE" 2>/dev/null)" = "attention" ] || break
        [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ] || break
        [ -w "$PTS" ] || break

        if [ $((counter % 2)) -eq 0 ]; then
            cwn_raw_title "$CWN_ATTENTION_LABEL" > "$PTS" 2>/dev/null || true
        else
            cwn_raw_title "$RESTING_TITLE" > "$PTS" 2>/dev/null || true
        fi
        sleep "$CWN_FLASH_INTERVAL"
        counter=$((counter + CWN_FLASH_INTERVAL))
    done
    cwn_log "flash: exit sid=$SID counter=$counter"
}

main "$@" || true
exit 0
