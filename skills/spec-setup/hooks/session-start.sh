#!/bin/sh
#
# session-start.sh — the ONE executable the harness calls at session start.
# Everything else in this directory is sourced from here.
#
# Flow: parse the hook payload on stdin ONCE (session_id, source), resolve
# credentials (environment first, then the credentials file), open ONE MCP
# session against the Speqq server, resolve the workspace, then run the
# steps in order under one shared wall-clock deadline (8 seconds total,
# SPEQQ_HOOK_TIMEOUT_SECONDS overrides):
#
#   speqq-setup.sh           run_speqq_setup        (skipped when source=compact)
#   spec-workspace-context.sh run_workspace_context (always)
#
# Each step is a sibling file defining one run_* function; adding a future
# step (say spec-active-work.sh defining run_active_work) is ONE more
# run_step line in main(). A missing step file is skipped with a single
# stderr line — steps ship independently and the dispatcher hard-depends on
# none of them.
#
# The invariants (never block, never silent, never leak the token, one
# deadline, stdout is sacred) are documented and enforced in lib.sh.

set -u

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || {
  printf 'speqq session-start: could not resolve its own directory\n' >&2
  exit 0
}

if [ ! -f "$SCRIPT_DIR/lib.sh" ]; then
  printf 'speqq session-start: lib.sh is missing from %s - skipping\n' "$SCRIPT_DIR" >&2
  exit 0
fi
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# Source a sibling step file and run the one function it defines. $1 = file
# name, $2 = function name. A step that is absent or malformed is skipped
# with one stderr line; it never takes the session (or the other steps) down.
run_step() {
  step_file="$SCRIPT_DIR/$1"
  step_function=$2
  if [ ! -f "$step_file" ]; then
    printf '%s: %s not found in %s - skipping %s\n' "$HOOK_NAME" "$1" "$SCRIPT_DIR" "$step_function" >&2
    return 0
  fi
  # shellcheck disable=SC1090
  . "$step_file"
  if ! command -v "$step_function" >/dev/null 2>&1; then
    printf '%s: %s defines no %s - skipping\n' "$HOOK_NAME" "$1" "$step_function" >&2
    return 0
  fi
  "$step_function"
}

main() {
  parse_hook_stdin
  resolve_credentials

  if [ "${SPEQQ_CONNECTED:-0}" -eq 0 ]; then
    # No credentials anywhere: a fresh clone, not an error. The setup step
    # turns this into onboarding context. Compaction reinjects working
    # context, and onboarding text is not working context — skip it there.
    if [ "${SPEQQ_SESSION_SOURCE:-}" = 'compact' ]; then
      printf '%s: no Speqq credentials in the environment or %s - skipping\n' \
        "$HOOK_NAME" "$SPEQQ_CREDENTIALS_PATH" >&2
      exit 0
    fi
    run_step speqq-setup.sh run_speqq_setup
    exit 0
  fi

  command -v curl >/dev/null 2>&1 || give_up 'curl is not on PATH'
  command -v python3 >/dev/null 2>&1 || give_up 'python3 is not on PATH'

  start_deadline
  make_work_dir
  write_curl_config
  open_session
  resolve_workspace

  # --- steps: one line per step, in injection order, one shared deadline ---
  if [ "${SPEQQ_SESSION_SOURCE:-}" != 'compact' ]; then
    run_step speqq-setup.sh run_speqq_setup
  fi
  run_step spec-workspace-context.sh run_workspace_context
  # A future step drops in here as one more run_step line.

  exit 0
}

main
