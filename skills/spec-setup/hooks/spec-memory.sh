#!/bin/sh
#
# spec-memory.sh — the write hook: record where the work stands at the two
# moments a session's context is about to be lost. PreCompact and SessionEnd
# fire this executable directly; it is NOT a step under the session-start
# dispatcher, because those events inject nothing — they record.
#
# Flow: parse the hook payload on stdin ONCE (session_id, and the event —
# PreCompact carries `trigger`, SessionEnd carries `reason`), resolve
# credentials, read the git state (current branch, dirty files), open ONE MCP
# session, resolve the workspace, find the ACTIVE spec — the queue item whose
# branch field exactly equals the current branch, taking its linked spec
# document — and append one line to that spec's MEMORY.md with
# spec_memory_append. The server stamps the time and composes the line; this
# hook sends only the facts: agent (SPEQQ_HOOK_AGENT, set by the wiring),
# session_id, and the snippet.
#
# The invariants (never block, never silent, never leak the token, one
# deadline) are documented and enforced in lib.sh, plus one of this hook's
# own: STDOUT STAYS EMPTY ON EVERY PATH. A write hook injects nothing — the
# recall after compaction is the SessionStart hooks' job.
#
# Every miss is a skip, not a failure: no credentials, no branch, no queue
# item claiming the branch — one stderr line naming the cause, exit 0,
# nothing written and nothing guessed.

set -u

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || {
  printf 'speqq spec-memory: could not resolve its own directory\n' >&2
  exit 0
}

if [ ! -f "$SCRIPT_DIR/lib.sh" ]; then
  printf 'speqq spec-memory: lib.sh is missing from %s - skipping\n' "$SCRIPT_DIR" >&2
  exit 0
fi
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# lib.sh names itself for the dispatcher; this hook reports as itself.
HOOK_NAME='speqq spec-memory'
CLIENT_NAME='speqq-spec-memory'

# Ceiling the server enforces on an agent name; validated here so a bad
# wiring drops the attribution with a named cause instead of losing the line.
SM_AGENT_MAX_CHARS=32

# ---------------------------------------------------------------------------
# Embedded python — one copy, build and parse modes, double quotes only so it
# survives the single-quoted shell string. `hook-stdin` and `resolve-spec`
# read stdin; the build modes never touch it.
# ---------------------------------------------------------------------------

SM_PYTHON='
import json
import re
import sys

MODE = sys.argv[1]


def fail(message):
    sys.stderr.write(message.replace("\n", " ") + "\n")
    raise SystemExit(1)


if MODE == "hook-stdin":
    # The harness hook payload. Four lines out: session_id, the event
    # (precompact / sessionend / empty when neither can be told), the
    # detail — PreCompact carries `trigger`, SessionEnd carries `reason`,
    # whichever is present lands in the one detail slot — and the transcript
    # path. Never fatal: a TTY stdin (a human running the script by hand)
    # reads as no payload.
    raw = "" if sys.stdin.isatty() else sys.stdin.read()
    try:
        payload = json.loads(raw)
    except ValueError:
        payload = {}
    if not isinstance(payload, dict):
        payload = {}

    def field(name, pattern):
        value = payload.get(name, "")
        if not isinstance(value, str):
            return ""
        return value if re.fullmatch(pattern, value) else ""

    trigger = field("trigger", r"[a-z_]{1,64}")
    reason = field("reason", r"[a-z_]{1,64}")
    event_name = payload.get("hook_event_name")
    if event_name == "PreCompact" or (event_name is None and trigger):
        event = "precompact"
    elif event_name == "SessionEnd" or (event_name is None and reason):
        event = "sessionend"
    else:
        event = ""
    transcript = payload.get("transcript_path", "")
    if not isinstance(transcript, str) or "\n" in transcript:
        transcript = ""
    sys.stdout.write(field("session_id", r"[A-Za-z0-9._-]{1,128}") + "\n")
    sys.stdout.write(event + "\n")
    sys.stdout.write((trigger or reason) + "\n")
    sys.stdout.write(transcript + "\n")
elif MODE == "transcript-tail":
    # The last thing the assistant said, clipped to one readable fragment —
    # what the session was WORKING ON when the snapshot fired. Read from the
    # harness transcript (JSONL, newest last); any shape surprise or missing
    # file is an empty answer, never an error. Only the tail of the file is
    # read: long-session transcripts can be huge, and this runs on the
    # compaction path.
    TAIL_BYTES = 262144
    CLIP = 180
    try:
        with open(sys.argv[2], "rb") as handle:
            handle.seek(0, 2)
            handle.seek(max(0, handle.tell() - TAIL_BYTES))
            lines = handle.read().decode("utf-8", "replace").splitlines()
    except OSError:
        raise SystemExit(0)
    fragment = ""
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if not isinstance(entry, dict) or entry.get("type") != "assistant":
            continue
        message = entry.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, list):
            continue
        text = " ".join(
            p.get("text", "") for p in content if isinstance(p, dict) and p.get("type") == "text"
        ).strip()
        if text:
            fragment = " ".join(text.split())
            break
    if len(fragment) > CLIP:
        fragment = fragment[:CLIP].rsplit(" ", 1)[0] + "..."
    sys.stdout.write(fragment + "\n")
elif MODE == "queue-args":
    sys.stdout.write(json.dumps({"workspace_id": sys.argv[2]}))
elif MODE == "append-args":
    # Attribution is one unit: agent and session_id go together or not at
    # all — the server rejects exactly one of them, so this never sends one.
    arguments = {"spec_id": sys.argv[2], "text": sys.argv[3]}
    agent, session_id = sys.argv[4], sys.argv[5]
    if agent and session_id:
        arguments["agent"] = agent
        arguments["session_id"] = session_id
    sys.stdout.write(json.dumps(arguments))
elif MODE == "resolve-spec":
    # queue_read structuredContent on stdin -> the active spec id: the queue
    # item whose branch field exactly equals the current branch, through its
    # linked spec document. Every miss names itself; nothing is guessed.
    branch = sys.argv[2]
    try:
        data = json.load(sys.stdin)
    except ValueError:
        fail("queue_read returned unreadable JSON")
    items = data.get("items") if isinstance(data, dict) else None
    if not isinstance(items, list):
        fail("queue_read returned no items list")
    matches = [i for i in items if isinstance(i, dict) and i.get("branch") == branch]
    if not matches:
        fail("no queue item claims branch " + branch + " - nothing to record against")
    spec_ids = []
    for item in matches:
        linked = item.get("linked_document_id")
        if isinstance(linked, str) and linked and linked not in spec_ids:
            spec_ids.append(linked)
    if not spec_ids:
        fail("the queue item on branch " + branch + " links no spec document")
    if len(spec_ids) > 1:
        fail(str(len(spec_ids)) + " specs claim branch " + branch + " - cannot pick one")
    sys.stdout.write(spec_ids[0] + "\n")
else:
    fail("unknown mode: " + MODE)
'

# ---------------------------------------------------------------------------
# Helpers, all sm_-prefixed so nothing in lib.sh is clobbered
# ---------------------------------------------------------------------------

# Parse the harness hook payload ONCE. Anything missing or unparseable
# becomes the empty string — never fatal, never blocking.
sm_parse_hook_stdin() {
  SM_SESSION_ID=''
  SM_EVENT=''
  # shellcheck disable=SC2034 # captured with the event per the hook contract
  SM_EVENT_DETAIL=''
  SM_TRANSCRIPT_PATH=''
  if command -v python3 >/dev/null 2>&1; then
    sm_stdin_fields=$(python3 -c "$SM_PYTHON" hook-stdin 2>/dev/null) || sm_stdin_fields=''
    SM_SESSION_ID=$(printf '%s\n' "$sm_stdin_fields" | sed -n '1p')
    SM_EVENT=$(printf '%s\n' "$sm_stdin_fields" | sed -n '2p')
    SM_EVENT_DETAIL=$(printf '%s\n' "$sm_stdin_fields" | sed -n '3p')
    SM_TRANSCRIPT_PATH=$(printf '%s\n' "$sm_stdin_fields" | sed -n '4p')
  fi
}

# What the session was working on, read from the tail of the harness
# transcript. Empty when there is no transcript, no readable assistant text,
# or any surprise at all — the snapshot is still worth writing without it.
sm_read_last_activity() {
  SM_LAST_ACTIVITY=''
  if [ -n "$SM_TRANSCRIPT_PATH" ] && [ -f "$SM_TRANSCRIPT_PATH" ]; then
    SM_LAST_ACTIVITY=$(python3 -c "$SM_PYTHON" transcript-tail "$SM_TRANSCRIPT_PATH" 2>/dev/null | sed -n '1p') ||
      SM_LAST_ACTIVITY=''
  fi
}

# Branch and dirty state, read once. An empty branch — outside a repo, on a
# detached HEAD — is the honest answer, and the caller skips on it.
sm_read_git_state() {
  SM_BRANCH=$(git branch --show-current 2>/dev/null) || SM_BRANCH=''
  SM_DIRTY_COUNT=0
  SM_DIRTY_NAMES=''
  sm_porcelain=$(git status --porcelain 2>/dev/null) || sm_porcelain=''
  if [ -n "$sm_porcelain" ]; then
    SM_DIRTY_COUNT=$(printf '%s\n' "$sm_porcelain" | wc -l | tr -d ' ')
    # The first three paths, joined ", " — a sample for the snippet; the
    # count already says how many there really are.
    SM_DIRTY_NAMES=$(printf '%s\n' "$sm_porcelain" | head -n 3 | cut -c 4- |
      awk 'NR > 1 { printf ", " } { printf "%s", $0 }')
  fi
}

# Attribution is agent + session_id together or neither. A missing or invalid
# half drops BOTH with one stderr line naming the cause, and the snippet is
# still recorded — an unattributed memory beats a lost one.
sm_resolve_attribution() {
  SM_AGENT=${SPEQQ_HOOK_AGENT:-}
  if [ -z "$SM_AGENT" ]; then
    printf '%s: SPEQQ_HOOK_AGENT is not set - recording without attribution\n' "$HOOK_NAME" >&2
    SM_SESSION_ID=''
    return 0
  fi
  case $SM_AGENT in
  *[!a-z0-9-]*)
    printf '%s: SPEQQ_HOOK_AGENT %s is not lowercase letters, digits, and hyphens - recording without attribution\n' \
      "$HOOK_NAME" "$SM_AGENT" >&2
    SM_AGENT=''
    SM_SESSION_ID=''
    return 0
    ;;
  esac
  if [ ${#SM_AGENT} -gt "$SM_AGENT_MAX_CHARS" ]; then
    printf '%s: SPEQQ_HOOK_AGENT %s is longer than %s characters - recording without attribution\n' \
      "$HOOK_NAME" "$SM_AGENT" "$SM_AGENT_MAX_CHARS" >&2
    SM_AGENT=''
    SM_SESSION_ID=''
    return 0
  fi
  if [ -z "$SM_SESSION_ID" ]; then
    printf '%s: the hook payload carried no session_id - recording without attribution\n' "$HOOK_NAME" >&2
    SM_AGENT=''
  fi
}

main() {
  sm_parse_hook_stdin
  resolve_credentials

  if [ "${SPEQQ_CONNECTED:-0}" -eq 0 ]; then
    # No credentials anywhere. The session-start hook answers this with setup
    # guidance; a write hook cannot — its stdout goes nowhere useful — so it
    # names the skip and steps aside.
    printf '%s: no Speqq credentials in the environment or %s - skipping\n' \
      "$HOOK_NAME" "$SPEQQ_CREDENTIALS_PATH" >&2
    exit 0
  fi

  command -v curl >/dev/null 2>&1 || give_up 'curl is not on PATH'
  command -v python3 >/dev/null 2>&1 || give_up 'python3 is not on PATH'
  command -v git >/dev/null 2>&1 || give_up 'git is not on PATH - cannot read the branch'

  [ -n "$SM_EVENT" ] || give_up 'the hook payload named neither PreCompact nor SessionEnd - skipping'

  sm_read_git_state
  [ -n "$SM_BRANCH" ] || give_up 'no current git branch - cannot resolve the active spec'

  sm_read_last_activity

  # One line, no timestamp: the server stamps the time and composes the line.
  # The transcript fragment is the part a reader actually wants — what the
  # session was doing — so it leads; the git facts follow as evidence.
  case $SM_EVENT in
  precompact)
    if [ "$SM_DIRTY_COUNT" -gt 0 ]; then
      SM_SNIPPET="compacting on $SM_BRANCH - dirty: $SM_DIRTY_COUNT files ($SM_DIRTY_NAMES)"
    else
      SM_SNIPPET="compacting on $SM_BRANCH - dirty: 0 files"
    fi
    [ -z "$SM_LAST_ACTIVITY" ] || SM_SNIPPET="$SM_SNIPPET - working on: $SM_LAST_ACTIVITY"
    ;;
  sessionend)
    SM_SNIPPET="session ended on $SM_BRANCH - dirty: $SM_DIRTY_COUNT files"
    [ -z "$SM_LAST_ACTIVITY" ] || SM_SNIPPET="$SM_SNIPPET - last: $SM_LAST_ACTIVITY"
    ;;
  esac

  sm_resolve_attribution

  start_deadline
  make_work_dir
  write_curl_config
  open_session
  resolve_workspace

  # The queue names the active work; the branch names which item is ours.
  sm_args=$(python3 -c "$SM_PYTHON" queue-args "$WORKSPACE_ID" 2>/dev/null) ||
    give_up 'could not build the queue_read arguments'
  call_tool queue_read "$sm_args"
  parse_response structured queue_read >"$WORK_DIR/sm-queue" ||
    give_up "could not read the queue: $(parse_error_line)"

  sm_spec_id=$(python3 -c "$SM_PYTHON" resolve-spec "$SM_BRANCH" <"$WORK_DIR/sm-queue" 2>"$WORK_DIR/sm-error") || {
    sm_cause=$(tail -n 1 "$WORK_DIR/sm-error" 2>/dev/null)
    [ -n "$sm_cause" ] || sm_cause='could not resolve the active spec from the queue'
    give_up "$sm_cause"
  }

  sm_args=$(python3 -c "$SM_PYTHON" append-args "$sm_spec_id" "$SM_SNIPPET" "$SM_AGENT" "$SM_SESSION_ID" 2>/dev/null) ||
    give_up 'could not build the spec_memory_append arguments'
  call_tool spec_memory_append "$sm_args"
  parse_response text spec_memory_append >/dev/null ||
    give_up "spec_memory_append did not confirm the write: $(parse_error_line)"

  exit 0
}

main
