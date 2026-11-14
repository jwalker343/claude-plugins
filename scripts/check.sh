#!/usr/bin/env bash
# Repo consistency checks. Run locally before committing; CI runs the same script.
# Requires: jq. Optional: shellcheck, claude (each check is skipped if its tool is missing,
# unless STRICT_TOOLS=1, which CI sets).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0 mark=0
err()  { echo "✘ $*" >&2; fail=$((fail+1)); }
ok()   { [ "$fail" = "$mark" ] && echo "✔ $*"; mark=$fail; }  # only if this section added no errors
need() {
  command -v "$1" >/dev/null && return 0
  if [ "${STRICT_TOOLS:-0}" = 1 ]; then err "$1 not installed"; else echo "- skipping: $1 not installed"; fi
  return 1
}

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

MKT=.claude-plugin/marketplace.json

# 1. Every JSON file parses
while IFS= read -r f; do
  jq empty "$f" 2>/dev/null || err "invalid JSON: $f"
done < <(git ls-files --cached --others --exclude-standard '*.json')
ok "JSON parses"

# 2. Marketplace entries <-> plugin directories
mapfile -t entries < <(jq -r '.plugins[].name' "$MKT")
for name in "${entries[@]}"; do
  src=$(jq -r --arg n "$name" '.plugins[] | select(.name==$n) | .source' "$MKT")
  [ "$src" = "./plugins/$name" ] || err "$name: source is '$src', expected './plugins/$name'"
  [ -d "plugins/$name" ] || err "$name: listed in marketplace but plugins/$name is missing"
done
for dir in plugins/*/; do
  name=$(basename "$dir")
  pj="$dir.claude-plugin/plugin.json"
  [ -f "$pj" ] || { err "$name: missing $pj"; continue; }

  [ "$(jq -r .name "$pj")" = "$name" ] || err "$name: plugin.json name does not match directory"
  printf '%s\n' "${entries[@]}" | grep -qx "$name" || err "$name: not listed in $MKT"

  pdesc=$(jq -r .description "$pj")
  mdesc=$(jq -r --arg n "$name" '.plugins[] | select(.name==$n) | .description' "$MKT")
  [ "$pdesc" = "$mdesc" ] || err "$name: description differs between plugin.json and marketplace.json"

  grep -q "^| \`$name\` |" README.md || err "$name: missing from the README plugin table"

  # Hook commands that reference ${CLAUDE_PLUGIN_ROOT}/... must point at executable files
  hj="${dir}hooks/hooks.json"
  if [ -f "$hj" ]; then
    # shellcheck disable=SC2016  # literal ${CLAUDE_PLUGIN_ROOT}, not an expansion
    while IFS= read -r rel; do
      f="$dir$rel"
      [ -f "$f" ] || { err "$name: hook references missing file $rel"; continue; }
      [ -x "$f" ] || err "$name: hook script $rel is not executable"
    done < <(jq -r '.. | .command? // empty' "$hj" | grep -o '\${CLAUDE_PLUGIN_ROOT}/[^"'\'' ]*' | sed 's|^\${CLAUDE_PLUGIN_ROOT}/||')
  fi
done
ok "marketplace, plugin dirs and README agree"

# 3. Shell scripts
mapfile -t shells < <(git ls-files --cached --others --exclude-standard '*.sh')
if [ ${#shells[@]} -gt 0 ] && need shellcheck; then
  shellcheck "${shells[@]}" || err "shellcheck failed"
  ok "shellcheck"
fi

# 4. Claude's own validator (strict: warnings fail too)
if need claude; then
  command claude plugin validate --strict . >/dev/null 2>&1 || { command claude plugin validate --strict .; err "marketplace validation"; }
  for dir in plugins/*/; do
    command claude plugin validate --strict "$dir" >/dev/null 2>&1 || { command claude plugin validate --strict "$dir"; err "validation: $dir"; }
  done
  ok "claude plugin validate --strict"
fi

if [ "$fail" = 0 ]; then
  echo "All checks passed."
else
  echo "$fail check(s) failed." >&2
  exit 1
fi
