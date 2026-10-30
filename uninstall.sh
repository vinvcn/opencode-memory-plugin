#!/usr/bin/env bash
# opencode-memory uninstaller — exact rollback driven by the install manifest.
#
# Usage:
#   uninstall.sh [--purge] [--force]
#     --purge  ALSO delete the memory data root (default: data is KEPT — it is
#              user data, not an install artifact)
#     --force  no manifest found? clean the known default locations anyway
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
PLUGINS_DIR="$OPENCODE_DIR/plugins"
POINTER="$PLUGINS_DIR/memory.data-root"
MARK_START='<!-- opencode-memory:start v1'
MARK_END='<!-- opencode-memory:end -->'

PURGE=0
FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --purge) PURGE=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

# data root resolution order: pointer file > env > default
DATA_ROOT=""
if [ -f "$POINTER" ]; then
  DATA_ROOT="$(head -1 "$POINTER")"
elif [ -n "${AGENT_MEMORY_HOME:-}" ]; then
  DATA_ROOT="$AGENT_MEMORY_HOME"
else
  DATA_ROOT="$HOME/.local/share/agent-memory"
fi
MANIFEST="$DATA_ROOT/.opencode-memory-manifest.json"

get() { { grep -o "\"$1\": \"[^\"]*\"" "$MANIFEST" 2>/dev/null || true; } | sed -n '1p' | sed "s/^\"$1\": \"//;s/\"\$//" ; }

strip_block() {
  # $1 = agents file; removes the marker-delimited block in place (atomic),
  # trimming trailing blank lines so repeated installs leave no drift
  local f="$1"
  [ -f "$f" ] || return 0
  local tmp
  tmp="$(mktemp "$(dirname "$f")/.agents-block.XXXXXX")"
  awk -v s="$MARK_START" -v e="$MARK_END" \
    'index($0,s){skip=1;next} index($0,e){skip=0;next} !skip{buf[n++]=$0}
     END{while(n>0 && buf[n-1]=="") n--; for(i=0;i<n;i++) print buf[i]}' \
    "$f" > "$tmp"
  mv "$tmp" "$f"
}

if [ ! -f "$MANIFEST" ]; then
  if [ "$FORCE" -ne 1 ]; then
    echo "error: no manifest at $MANIFEST" >&2
    echo "nothing to do (or pass --force to clean default locations)" >&2
    exit 1
  fi
  echo "==> no manifest; forced cleanup of default locations"
  rm -f "$PLUGINS_DIR/memory.ts" "$POINTER"
  strip_block "$OPENCODE_DIR/AGENTS.md"
  rmdir "$PLUGINS_DIR" 2>/dev/null || true
  if [ "$PURGE" -eq 1 ]; then rm -rf "$DATA_ROOT"; echo "==> data root purged: $DATA_ROOT"; fi
  echo "==> done."
  exit 0
fi

PLUGIN_PATH="$(get plugin_path)"
AGENTS_FILE="$(get agents_file)"
PROJ_PLUGIN="$(get project_plugin_path)"

# 1. plugin files
[ -n "$PLUGIN_PATH" ] && rm -f "$PLUGIN_PATH" && echo "==> removed: $PLUGIN_PATH"
if [ -n "$PROJ_PLUGIN" ] && [ "$PROJ_PLUGIN" != "$PLUGIN_PATH" ]; then
  rm -f "$PROJ_PLUGIN" && echo "==> removed: $PROJ_PLUGIN"
fi
rmdir "$PLUGINS_DIR" 2>/dev/null || true

# 2. managed AGENTS.md block
if [ -n "$AGENTS_FILE" ]; then
  strip_block "$AGENTS_FILE"
  echo "==> managed block removed: $AGENTS_FILE"
fi

# 3. data-root pointer
[ -f "$POINTER" ] && rm -f "$POINTER" && echo "==> removed: $POINTER"

# 4. manifest
rm -f "$MANIFEST"

# 5. data root
if [ "$PURGE" -eq 1 ]; then
  rm -rf "$DATA_ROOT"
  echo "==> data root PURGED: $DATA_ROOT"
else
  echo "==> memory data KEPT at: $DATA_ROOT"
  echo "    (it is your data, not an install artifact; delete with: uninstall.sh --purge)"
fi

echo "==> opencode-memory uninstalled. Restart opencode to drop the plugin from new sessions."
