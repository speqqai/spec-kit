# shellcheck shell=sh
#
# speqq-setup.sh — the connection step of the Speqq session-start dispatcher.
# Sourced by session-start.sh after lib.sh; never executed directly.
#
# Connected (credentials resolved, MCP session open, workspace resolved by
# the dispatcher before this runs): print exactly ONE stdout line confirming
# the connection, so the agent knows Speqq is live without a probe call.
#
# Not connected (no credentials anywhere — no environment variables and no
# credentials file): print a short stdout block that tells the AGENT how to
# walk the user through connecting. That block IS the session context for a
# fresh clone; it is deliberately not an error path. The token itself is the
# user's alone: the agent never asks for it, never reads it, never echoes it.

case ${0##*/} in
speqq-setup.sh)
  printf 'speqq session-start: speqq-setup.sh is a step library - run session-start.sh instead\n' >&2
  exit 0
  ;;
esac

print_speqq_setup_guidance() {
  cat <<GUIDANCE
Speqq is not connected for this repository.
Agent: offer to walk the user through connecting Speqq. Every step below is
the USER's own action - never ask for, collect, read, or echo the token.
1. The user creates a token in Speqq under Settings -> MCP Tokens.
2. The user adds the Speqq MCP server to their agent, pasting their own URL
   and token into the command themselves. For Claude Code:
   claude mcp add --transport http speqq <speqq-mcp-url> --header "Authorization: Bearer <token>"
3. So session hooks can authenticate too, the user creates
   ${SPEQQ_CREDENTIALS_PATH:-$HOME/.speqq/credentials} with mode 600
   (chmod 600) and pastes these three lines with their own values:
   SPEQQ_MCP_URL=<speqq-mcp-url>
   SPEQQ_MCP_TOKEN=<token>
   SPEQQ_WORKSPACE_ID=<workspace-id>   (optional when the token sees exactly one)
New sessions connect automatically once that file exists.
GUIDANCE
}

# One stdout line when connected; the onboarding block when not.
run_speqq_setup() {
  if [ "${SPEQQ_CONNECTED:-0}" -eq 0 ]; then
    print_speqq_setup_guidance
    return 0
  fi
  if [ -z "${WORKSPACE_ID:-}" ] || [ -z "${WORKSPACE_NAME:-}" ]; then
    give_up 'run_speqq_setup was called before the workspace was resolved'
  fi
  session_short=$(printf '%s' "${SPEQQ_HARNESS_SESSION_ID:-}" | cut -c 1-8)
  [ -n "$session_short" ] || session_short='unknown'
  printf 'Speqq connected - workspace %s (%s) - session %s\n' \
    "$WORKSPACE_NAME" "$WORKSPACE_ID" "$session_short"
}
