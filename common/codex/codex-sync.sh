#!/usr/bin/env bash
#
# codex-sync - apply the portable Codex baseline on this machine.
#
# This sync is intentionally conservative:
#   1. AGENTS.md is linked from common/codex into ~/.codex.
#   2. selected local skills are linked individually into ~/.codex/skills.
#   3. config.toml is merged, not symlinked, so manual Codex plugins,
#      trusted projects, existing MCP servers, and app settings are preserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_SRC="$SCRIPT_DIR"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

echo "- Syncing Codex configs..."

mkdir -p "$CODEX_HOME" "$CODEX_HOME/skills"

link_item() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if [ -f "$dst" ] && [ -f "$src" ] && ! cmp -s "$dst" "$src"; then
      local backup="$dst.drift-$(date +%Y%m%d-%H%M%S)"
      mv "$dst" "$backup"
      echo "  ! $label was a plain file differing from the repo; saved as $(basename "$backup")."
    else
      mv "$dst" "$dst.pre-dotfiles"
      echo "  (backed up existing $label -> $(basename "$dst").pre-dotfiles)"
    fi
  fi

  ln -sfn "$src" "$dst"
  echo "  Linked $label"
}

link_item "$CODEX_SRC/AGENTS.md" "$CODEX_HOME/AGENTS.md" "AGENTS.md"

if [ -d "$CODEX_SRC/skills" ]; then
  for skill_dir in "$CODEX_SRC"/skills/*; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue
    skill_name="$(basename "$skill_dir")"
    link_item "$skill_dir" "$CODEX_HOME/skills/$skill_name" "skills/$skill_name"
  done
fi

# The merge needs python3 >= 3.11 (tomllib). Stock macOS ships no python3 at all
# (just the Xcode CLT stub), so this must DEGRADE, not abort: under `set -e` a
# non-zero exit here would kill codex-sync — and with it the tail of install.sh —
# after AGENTS.md and the skills have already been linked.
if ! command -v python3 >/dev/null 2>&1; then
  echo "  ! python3 not found; skipped config.toml merge."
  echo "    Install Python 3.11+, then re-run codex-sync to apply $CODEX_SRC/config.toml."
elif ! python3 -c 'import tomllib' >/dev/null 2>&1; then
  echo "  ! python3 is too old for tomllib (needs 3.11+); skipped config.toml merge."
  echo "    Upgrade Python, then re-run codex-sync to apply $CODEX_SRC/config.toml."
else
python3 - "$CODEX_SRC/config.toml" "$CODEX_HOME/config.toml" <<'PY'
import re
import sys
import tomllib
from pathlib import Path

source_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])

source = tomllib.loads(source_path.read_text())
target_text = target_path.read_text() if target_path.exists() else ""
lines = target_text.splitlines()

managed_scalars = {
    key: value
    for key, value in source.items()
    if key != "mcp_servers" and not isinstance(value, dict)
}
managed_mcp = source.get("mcp_servers", {})


def format_value(value):
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def first_table_index(current_lines):
    for index, line in enumerate(current_lines):
        if re.match(r"\s*\[", line):
            return index
    return len(current_lines)


def upsert_root_scalar(current_lines, key, value):
    pattern = re.compile(rf"^(\s*){re.escape(key)}\s*=")
    table_start = first_table_index(current_lines)
    replacement = f"{key} = {format_value(value)}"
    for index in range(table_start):
        if pattern.match(current_lines[index]):
            current_lines[index] = replacement
            return current_lines
    current_lines.insert(table_start, replacement)
    return current_lines


def find_table(current_lines, header):
    start = None
    pattern = re.compile(rf"^\s*\[{re.escape(header)}\]\s*$")
    next_table = re.compile(r"^\s*\[")
    for index, line in enumerate(current_lines):
        if start is None:
            if pattern.match(line):
                start = index
        elif next_table.match(line):
            return start, index
    if start is None:
        return None
    return start, len(current_lines)


def upsert_table_key(current_lines, header, key, value):
    found = find_table(current_lines, header)
    assignment = f"{key} = {format_value(value)}"
    if found is None:
        if current_lines and current_lines[-1].strip():
            current_lines.append("")
        current_lines.append(f"[{header}]")
        current_lines.append(assignment)
        return current_lines

    start, end = found
    pattern = re.compile(rf"^(\s*){re.escape(key)}\s*=")
    for index in range(start + 1, end):
        if pattern.match(current_lines[index]):
            current_lines[index] = assignment
            return current_lines
    current_lines.insert(end, assignment)
    return current_lines


for key, value in managed_scalars.items():
    lines = upsert_root_scalar(lines, key, value)

for server_name, server_config in managed_mcp.items():
    if not isinstance(server_config, dict) or "url" not in server_config:
        continue
    lines = upsert_table_key(lines, f"mcp_servers.{server_name}", "url", server_config["url"])

next_text = "\n".join(lines).rstrip() + "\n"
if next_text != target_text:
    target_path.write_text(next_text)
    print("  Merged config.toml")
else:
    print("  config.toml already up to date")
PY
fi

echo "Codex config synced."
