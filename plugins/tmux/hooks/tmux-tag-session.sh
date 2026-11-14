#!/usr/bin/env bash
# Tag the tmux pane with this Claude session id
[ -n "$TMUX_PANE" ] || exit 0
id=$(jq -r .session_id)
[ -n "$id" ] && [ "$id" != null ] || exit 0
tmux set -p -t "$TMUX_PANE" @claude_session "$id"
