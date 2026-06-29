#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Codebase Map generator — symbol + structure index for AI agents.
# Scan the project ONCE, persist a digest, so new AI conversations read this
# instead of re-scanning hundreds of files. Re-run after structural changes.
#
#   Usage:  bash tools/gen_codebase_map.sh   (run from anywhere; it locates itself)
#
# Output goes to the in-repo Obsidian vault: docs/project/Codebase Map.md
# NOTE: the map is a SNAPSHOT — always verify a path/func/line against the live
# file before editing code.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# Project root = parent of this script's tools/ dir (portable, no hardcoded path).
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$PROJECT_ROOT/docs/project/Codebase Map.md"

cd "$PROJECT_ROOT"
mkdir -p "$(dirname "$OUT")"

emit_funcs() { grep -nE '^(static[[:space:]]+)?func ' "$1" 2>/dev/null | sed 's/^/    /' || true; }
first_doc()  { grep -m1 -E '^##' "$1" 2>/dev/null | sed 's/^##[[:space:]]*//' || true; }

{
  echo "# Codebase Map (auto-generated)"
  echo
  echo "> Quay về [[🎯 Project Index]]"
  echo ">"
  echo "> **AUTO-GENERATED — đừng sửa tay.** Regenerate: \`bash tools/gen_codebase_map.sh\` từ project root."
  echo "> Generated: $(date '+%Y-%m-%d %H:%M')"
  echo ">"
  echo "> ⚠️ Đây là SNAPSHOT. Verify path / func / line ở file thật trước khi sửa code."
  echo

  echo "## Autoloads (project.godot)"
  echo '```ini'
  awk '/^\[autoload\]/{f=1;next} /^\[/{f=0} f && NF' project.godot
  echo '```'
  echo

  echo "## Input actions (project.godot)"
  echo '```'
  awk '/^\[input\]/{f=1;next} /^\[/{f=0} f && /=\{/{sub(/=.*/,"");print}' project.godot
  echo '```'
  echo

  echo "## Project scripts — \`Scripts/\` (detailed: class_name · extends · funcs)"
  echo
  while IFS= read -r f; do
    cn=$(grep -m1 -E '^class_name ' "$f" 2>/dev/null | sed 's/class_name //' || true)
    ex=$(grep -m1 -E '^extends ' "$f" 2>/dev/null | sed 's/extends //' || true)
    echo "### \`$f\`"
    [ -n "$cn" ] && echo "- class_name: \`$cn\`"
    [ -n "$ex" ] && echo "- extends: \`$ex\`"
    echo "- funcs:"
    echo '```gdscript'
    emit_funcs "$f"
    echo '```'
    echo
  done < <(find Scripts -name '*.gd' 2>/dev/null | sort)

  echo "## addons/cogito — class index (shallow: class_name · extends · role)"
  echo
  echo "| class_name | extends | file | role (first ## doc) |"
  echo "|---|---|---|---|"
  while IFS= read -r f; do
    cn=$(grep -m1 -E '^class_name ' "$f" 2>/dev/null | sed 's/class_name //' || true)
    [ -z "$cn" ] && continue
    ex=$(grep -m1 -E '^extends ' "$f" 2>/dev/null | sed 's/extends //' || true)
    doc=$(first_doc "$f")
    rel="${f#./}"
    echo "| \`$cn\` | \`${ex:-?}\` | $rel | ${doc:-} |"
  done < <(find addons/cogito -name '*.gd' 2>/dev/null | sort)
  echo

  echo "## Project scenes — \`Scene/\` (root node + script)"
  echo
  echo "| scene | root node | script ext_resources |"
  echo "|---|---|---|"
  while IFS= read -r s; do
    root=$(grep -m1 -E '^\[node ' "$s" 2>/dev/null | sed -E 's/\[node name="([^"]*)".*type="([^"]*)".*/\1 (\2)/; t; s/\[node name="([^"]*)".*/\1 (instanced)/' || true)
    scripts=$(grep -E '^\[ext_resource .*type="Script"' "$s" 2>/dev/null | sed -E 's/.*path="([^"]*)".*/\1/' | tr '\n' ' ' || true)
    rel="${s#./}"
    echo "| $rel | ${root:-?} | ${scripts:-} |"
  done < <(find Scene -name '*.tscn' 2>/dev/null | sort)
  echo

  echo "---"
  echo "_Stats: $(find Scripts -name '*.gd' | wc -l) project scripts · $(find addons/cogito -name '*.gd' | wc -l) cogito scripts · $(find Scene -name '*.tscn' | wc -l) project scenes._"
} > "$OUT"

echo "Wrote codebase map -> $OUT"
