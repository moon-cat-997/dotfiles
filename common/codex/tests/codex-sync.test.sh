#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

mkdir -p "$tmp_home/.codex"
cat > "$tmp_home/.codex/config.toml" <<'TOML'
personality = "friendly"
model = "gpt-manual"

[projects."/tmp/example"]
trust_level = "trusted"

[plugins."gmail@openai-curated"]
enabled = true

[mcp_servers.figma]
url = "https://mcp.figma.com/mcp"
TOML

HOME="$tmp_home" bash "$repo_root/common/codex/codex-sync.sh" >/tmp/codex-sync-test.out
HOME="$tmp_home" bash "$repo_root/common/codex/codex-sync.sh" >/tmp/codex-sync-test-second.out

config="$tmp_home/.codex/config.toml"

[ -L "$tmp_home/.codex/AGENTS.md" ]
[ -L "$tmp_home/.codex/skills/dm812-project-setup" ]
[ -L "$tmp_home/.codex/skills/dm812-memory-audit" ]

grep -q 'personality = "pragmatic"' "$config"
grep -q 'model = "gpt-5.5"' "$config"
grep -q 'model_reasoning_effort = "medium"' "$config"
grep -q '\[mcp_servers.base44\]' "$config"
grep -q 'url = "https://app.base44.com/mcp"' "$config"
grep -q '\[mcp_servers.context7\]' "$config"
grep -q '\[mcp_servers.Jam\]' "$config"
grep -q '\[mcp_servers.mobbin\]' "$config"

grep -q '\[mcp_servers.figma\]' "$config"
grep -q '\[plugins."gmail@openai-curated"\]' "$config"
grep -q '\[projects."/tmp/example"\]' "$config"

if [ "$(grep -c '\[mcp_servers.base44\]' "$config")" -ne 1 ]; then
  echo "base44 MCP table duplicated" >&2
  exit 1
fi

if [ "$(grep -c 'model_reasoning_effort = "medium"' "$config")" -ne 1 ]; then
  echo "model_reasoning_effort duplicated" >&2
  exit 1
fi

python3 - "$config" <<'PY'
import sys
import tomllib
from pathlib import Path

tomllib.loads(Path(sys.argv[1]).read_text())
PY
