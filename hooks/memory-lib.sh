# shellcheck shell=sh
# Read the optional repository-local shared-memory handle without executing
# .speqq. The handle is returned without @, as the Knowledge MCP expects.

speqq_memory_handle() {
  command -v python3 >/dev/null 2>&1 || return 1
  speqq_repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
  speqq_config="$speqq_repo_root/.speqq"
  [ -f "$speqq_config" ] || return 0

  python3 - "$speqq_config" <<'PY'
import re
import sys
from pathlib import Path

try:
    lines = Path(sys.argv[1]).read_text().splitlines()
except OSError as exc:
    print(f"speqq hooks: could not read .speqq: {exc}", file=sys.stderr)
    sys.exit(1)

matches = [line for line in lines if re.match(r"^\s*memory\s*:", line)]
if not matches:
    sys.exit(0)
if len(matches) != 1:
    print("speqq hooks: .speqq must contain one memory: @handle line", file=sys.stderr)
    sys.exit(1)
match = re.fullmatch(r"\s*memory\s*:\s*@([a-z0-9][a-z0-9-]{0,62})\s*", matches[0])
if match is None:
    print("speqq hooks: invalid memory handle in .speqq", file=sys.stderr)
    sys.exit(1)
print(match.group(1))
PY
}
