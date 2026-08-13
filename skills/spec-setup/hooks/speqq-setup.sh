# shellcheck shell=sh
#
# speqq-setup.sh — the connection-status step of the Speqq session-start
# dispatcher. Sourced by session-start.sh after lib.sh; never executed
# directly.
#
# Runs only in rich mode (a hook token resolved, MCP session open, workspace
# resolved by the dispatcher before this runs): prints exactly ONE stdout
# line confirming the connection, so the agent knows Speqq is live without a
# probe call. The no-token case never reaches this step — the dispatcher
# injects the orient instruction instead (spec-orient-instruction.sh).

case ${0##*/} in
speqq-setup.sh)
  printf 'speqq session-start: speqq-setup.sh is a step library - run session-start.sh instead\n' >&2
  exit 0
  ;;
esac

run_speqq_setup() {
  if [ "${SPEQQ_CONNECTED:-0}" -eq 0 ]; then
    give_up 'run_speqq_setup was called without a resolved connection'
  fi
  if [ -z "${WORKSPACE_ID:-}" ] || [ -z "${WORKSPACE_NAME:-}" ]; then
    give_up 'run_speqq_setup was called before the workspace was resolved'
  fi
  session_short=$(printf '%s' "${SPEQQ_HARNESS_SESSION_ID:-}" | cut -c 1-8)
  [ -n "$session_short" ] || session_short='unknown'
  printf 'Speqq connected - workspace %s (%s) - session %s\n' \
    "$WORKSPACE_NAME" "$WORKSPACE_ID" "$session_short"
}
