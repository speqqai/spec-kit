#!/bin/sh
# spec-read-first.sh - recommendation-only nudge toward the Speqq context
# engine. Runs on PostToolUse after filesystem-search tool calls and injects
# ONE recommendation per session to try semantic_search_nodes / search_nodes /
# get_context before further grepping. It never blocks anything: exit 0 with
# no output is the common path. Disable with SPEQQ_READ_FIRST=0.

[ "${SPEQQ_READ_FIRST:-1}" = "0" ] && exit 0

payload=$(cat 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0

printf '%s' "$payload" | python3 -c "
import json, sys, re

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = str(data.get(\"tool_name\") or data.get(\"tool\") or \"\")
raw = data.get(\"tool_input\") or {}
command = raw.get(\"command\") if isinstance(raw, dict) else \"\"
if isinstance(command, list):
    command = \" \".join(str(part) for part in command)
command = str(command or \"\")

searchy = False
if tool in (\"Grep\", \"Glob\"):
    searchy = True
elif tool.lower() in (\"bash\", \"shell\") or command:
    if re.search(r\"(^|[;&|(\\s/])(grep|rg|ag|find)\\s\", \" \" + command):
        searchy = True

sys.exit(0 if not searchy else 3)
"
[ $? -eq 3 ] || exit 0

session=$(printf '%s' "$payload" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
print(str(data.get(\"session_id\") or \"\")[:8])
")
flag="${TMPDIR:-/tmp}/speqq-read-first-${session:-any}"
[ -f "$flag" ] && exit 0
: > "$flag" 2>/dev/null || exit 0

cat <<'ENVELOPE'
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Recommendation: this workspace has a Speqq context engine - for understanding the codebase, try semantic_search_nodes, search_nodes, or get_context over the Speqq MCP connection before more filesystem search. Grep and glob remain the fallback when Speqq does not answer. This tip appears once per session."}}
ENVELOPE
exit 0
