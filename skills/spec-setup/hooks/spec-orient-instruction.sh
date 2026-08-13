# shellcheck shell=sh
#
# spec-orient-instruction.sh — instruction-mode session start. When no hook
# token exists, the dispatcher injects this ONE instruction instead of
# fetched context, and the AGENT orients itself over its own MCP connection
# — the one the harness authenticated (OAuth or otherwise). No network, no
# credentials: the only things the hook contributes are timing and the two
# facts it can read locally without secrets — the current git branch, and
# the non-secret workspace id line of the credentials file when one exists.
#
# stdout here IS the injection. Rich mode (a hook token present) never
# reaches this step; the dispatcher fetches and injects real content
# instead.

case ${0##*/} in
spec-orient-instruction.sh)
  printf 'speqq session-start: spec-orient-instruction.sh is a step library - run session-start.sh instead\n' >&2
  exit 0
  ;;
esac

run_orient_instruction() {
  soi_branch=$(git branch --show-current 2>/dev/null) || soi_branch=''
  soi_agent=${SPEQQ_HOOK_AGENT:-claude-code}
  soi_session=$(printf '%s' "${SPEQQ_HARNESS_SESSION_ID:-}" | cut -c 1-8)

  soi_creds=${SPEQQ_CREDENTIALS_PATH:-$HOME/.speqq/credentials}
  soi_workspace=${SPEQQ_WORKSPACE_ID:-}
  if [ -z "$soi_workspace" ] && [ -f "$soi_creds" ]; then
    soi_workspace=$(sed -n 's/^SPEQQ_WORKSPACE_ID=//p' "$soi_creds" | tail -n 1 | tr -d '\r')
  fi
  if [ -n "$soi_workspace" ]; then
    soi_pick="use workspace $soi_workspace"
  else
    soi_pick="one visible: use it; several: ask the user which"
  fi

  cat <<INSTRUCTION
Orient in Speqq before starting the task, using your own MCP tools:
1. Call list_workspaces ($soi_pick). If the Speqq MCP tools are not
   available in this session, tell the user Speqq is not connected, offer
   the spec-setup skill, and continue without orientation.
2. Call spec_orient with that workspace${soi_branch:+ and branch "$soi_branch"} - it returns the
   product brief pointer, the open work, and the active spec. Read the
   PRODUCT.md pointer with spec_read when it names one, and the active
   spec's memory with spec_memory_read.
3. Then proceed with the user's request, oriented.
Throughout this session, heavily prefer the Speqq context engine for
understanding this codebase: reach for semantic_search_nodes, search_nodes,
and get_context BEFORE filesystem search (grep, glob, directory listing).
Filesystem search is the fallback when Speqq does not answer, not the
default.${soi_session:+
You are session $soi_session ($soi_agent). Memory lines carry the session that
wrote them - lines from other sessions are earlier work; read them as a
handoff, not your own memory.}
INSTRUCTION
}
