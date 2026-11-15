#!/bin/sh
# stop-flash.sh — manually stop the flasher and restore the resting title.
# Args: SID (required)

main() {
    SID="$1"
    DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || return 0
    . "$DIR/lib.sh" || return 0
    cwn_load_config

    if [ -z "$SID" ]; then
        cwn_log "stop-flash: SID required"
        return 0
    fi

    pid_file=$(cwn_pid_file "$SID")
    if [ -f "$pid_file" ]; then
        flash_pid=$(cat "$pid_file" 2>/dev/null)
        if [ -n "$flash_pid" ] && kill -0 "$flash_pid" 2>/dev/null; then
            cwn_log "stop-flash: killing pid=$flash_pid sid=$SID"
            kill "$flash_pid" 2>/dev/null || true
        fi
        rm -f "$pid_file" 2>/dev/null || true
    fi

    rm -f "$(cwn_state_file "$SID")" 2>/dev/null || true

    # The flasher restores the title via its own EXIT trap; this is a backstop
    # for when it was already gone (stale pid file).
    pts=$(cwn_find_pts)
    if [ -n "$pts" ] && [ -w "$pts" ]; then
        cwn_raw_title "$(cwn_resting_title "$PWD" "$SID")" > "$pts" 2>/dev/null || true
        cwn_log "stop-flash: restored resting title on $pts"
    fi
}

main "$@" || true
exit 0
