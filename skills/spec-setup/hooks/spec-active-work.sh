# shellcheck shell=sh
#
# spec-active-work.sh — SessionStart step: inject the open work and the active
# spec's memory tail — the recall half of the memory system spec-memory.sh and
# the checkpoint ladder write into. Sourced by session-start.sh, never
# executed; defines run_active_work(). Requires lib.sh sourced first
# ($WORK_DIR, post_rpc, parse_response, the open MCP session, and the
# workspace resolved).
#
# Read path:
#   1. queue_read (workspace_id) — the workspace queue. Top-level items that
#      are in progress or todo become the "Open work:" listing (in-progress
#      first, up to 8); the item whose branch field exactly equals the current
#      git branch is the ACTIVE item, through its linked spec document.
#   2. spec_memory_read (spec_id = the active item's linked_document_id,
#      limit 12) — the spec's MEMORY.md tail, printed verbatim, newest last.
#
# Invariants, same as every step under this dispatcher:
#   - never blocks: run_active_work() always returns 0
#   - never silent: every failure prints exactly ONE stderr line naming the cause
#   - stdout is sacred: each section is buffered and printed whole or not at all;
#     a failure mid-run keeps every section already printed and loses only the rest
#
# Every miss is a line, not a failure: no current branch, no queue item
# claiming the branch, no linked spec — one honest stdout line naming which,
# and the open-work listing still prints. The identity coda prints whenever a
# session id is known, so the agent can tell its own memory lines from
# another session's.

case ${0##*/} in
spec-active-work.sh)
  printf 'speqq session-start: spec-active-work.sh is a step library - run session-start.sh instead\n' >&2
  exit 0
  ;;
esac

SAW_STEP_NAME='speqq active-work'

# How many queue items the open-work listing shows, and how many memory
# snippets the tail carries. Past either cap the note names the exact call
# that fetches the rest.
SAW_MAX_OPEN_ITEMS=8
SAW_MEMORY_LIMIT=12

# ---------------------------------------------------------------------------
# Embedded python — one copy, argument-builder and render modes, double quotes
# only so it survives the single-quoted shell string. The render modes read
# plain structuredContent JSON on stdin (extracted by parse_response); the
# build modes never touch stdin.
# ---------------------------------------------------------------------------

SAW_PYTHON='
import json
import sys

MODE = sys.argv[1]
MAX_OPEN_ITEMS = int(sys.argv[2]) if MODE == "render-queue" else 0


def fail(message):
    sys.stderr.write(message.replace("\n", " ") + "\n")
    raise SystemExit(1)


def load_items(label):
    try:
        data = json.load(sys.stdin)
    except ValueError:
        fail(label + " returned unreadable JSON")
    items = data.get("items") if isinstance(data, dict) else None
    if not isinstance(items, list):
        fail(label + " returned no items list")
    return [item for item in items if isinstance(item, dict)]


def status_key(item):
    value = item.get("status_value")
    return value if isinstance(value, str) else ""


def status_label(item):
    label = item.get("status")
    if isinstance(label, str) and label:
        return label
    return status_key(item) or "no status"


def open_items(items):
    # In-progress first, then todo, queue order kept within each group.
    ordered = []
    for wanted in ("in_progress", "todo"):
        ordered.extend(item for item in items if status_key(item) == wanted)
    return ordered


if MODE == "queue-args":
    sys.stdout.write(json.dumps({"workspace_id": sys.argv[2]}))
elif MODE == "memory-args":
    sys.stdout.write(json.dumps({"spec_id": sys.argv[2], "limit": int(sys.argv[3])}))
elif MODE == "render-queue":
    # queue_read structuredContent -> the "Open work:" section.
    items = load_items("queue_read")
    if not items:
        sys.stdout.write("Open work: the queue is empty.\n")
        raise SystemExit(0)
    work = open_items(items)
    if not work:
        sys.stdout.write(
            "Open work: nothing in progress or todo ({0} queue items in other states).\n".format(len(items))
        )
        raise SystemExit(0)
    sys.stdout.write("Open work:\n")
    for item in work[:MAX_OPEN_ITEMS]:
        title = item.get("title") or item.get("id") or "untitled"
        line = "- {0} [{1}]".format(title, status_label(item))
        branch = item.get("branch")
        if isinstance(branch, str) and branch:
            line = line + " - " + branch
        sys.stdout.write(line.replace("\n", " ") + "\n")
    extra = len(work) - MAX_OPEN_ITEMS
    if extra > 0:
        sys.stdout.write(
            "[+{0} more in progress or todo - queue_read lists them all]\n".format(extra)
        )
elif MODE == "active-spec":
    # queue_read structuredContent -> the active spec, or the named miss.
    # One line out: "hit<TAB>spec_id<TAB>title" or "miss<TAB>honest line".
    # Every miss names itself; nothing is guessed.
    branch = sys.argv[2]
    items = load_items("queue_read")
    if not branch:
        sys.stdout.write("miss\tNo active spec: no current git branch to match against the queue.\n")
        raise SystemExit(0)
    matches = [item for item in items if item.get("branch") == branch]
    if not matches:
        sys.stdout.write("miss\tNo active spec: no queue item claims branch {0}.\n".format(branch))
        raise SystemExit(0)
    spec_ids = []
    title = ""
    for item in matches:
        linked = item.get("linked_document_id")
        if isinstance(linked, str) and linked and linked not in spec_ids:
            spec_ids.append(linked)
            if not title and isinstance(item.get("title"), str):
                title = item["title"]
    if not spec_ids:
        sys.stdout.write(
            "miss\tNo active spec: the queue item on branch {0} links no spec document.\n".format(branch)
        )
        raise SystemExit(0)
    if len(spec_ids) > 1:
        sys.stdout.write(
            "miss\tNo active spec: {0} specs claim branch {1} - cannot pick one.\n".format(len(spec_ids), branch)
        )
        raise SystemExit(0)
    clean_title = " ".join(title.split())
    sys.stdout.write("hit\t" + spec_ids[0] + "\t" + clean_title + "\n")
elif MODE == "render-memory":
    # spec_memory_read structuredContent -> the header and the verbatim tail.
    display = sys.argv[2]
    try:
        data = json.load(sys.stdin)
    except ValueError:
        fail("spec_memory_read returned unreadable JSON")
    snippets = data.get("snippets") if isinstance(data, dict) else None
    if not isinstance(snippets, list):
        fail("spec_memory_read returned no snippets list")
    sys.stdout.write("Active spec: " + display + "\n")
    if not snippets:
        sys.stdout.write("Memory tail: nothing recorded yet.\n")
        raise SystemExit(0)
    sys.stdout.write("Memory tail (newest last):\n")
    for snippet in snippets:
        sys.stdout.write(str(snippet) + "\n")
    if data.get("truncated"):
        sys.stdout.write(
            "[showing the last {0} of {1} - spec_memory_read with a higher limit returns more]\n".format(
                len(snippets), data.get("total")
            )
        )
else:
    fail("unknown mode: " + MODE)
'

# ---------------------------------------------------------------------------
# Helpers, all saw_-prefixed so nothing in lib.sh or a sibling step is clobbered
# ---------------------------------------------------------------------------

# The only way this step reports trouble: one stderr line, non-zero return.
# Callers must never pass the token into `reason`.
saw_fail() {
  printf '%s: %s\n' "$SAW_STEP_NAME" "$1" >&2
  return 1
}

saw_error_line() {
  tail -n 1 "$WORK_DIR/saw-error" 2>/dev/null
}

# Empty outside a repo, on a detached HEAD, or without git — all cases where
# the honest answer is no branch at all, and the miss line says so.
saw_current_branch() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi
  git branch --show-current 2>/dev/null || :
}

# One tools/call that fails SOFT: unlike lib.sh call_tool (whose give_up exits
# the dispatcher), a failure here returns 1 so the sections already printed
# survive and the steps after this one still run. Reuses lib.sh RPC_ID so ids
# stay unique on the shared session. $1 = tool name, $2 = JSON arguments.
saw_call() {
  RPC_ID=$((RPC_ID + 1))
  if ! python3 -c "$PYTHON_BUILD_CALL" "$RPC_ID" "$1" "$2" >"$WORK_DIR/request" 2>/dev/null; then
    saw_fail "could not build the $1 request"
    return 1
  fi
  if ! post_rpc "$WORK_DIR/request" "$WORK_DIR/response"; then
    saw_fail "$1 failed (${HTTP_STATUS:-unknown})"
    return 1
  fi
}

# The whole step. Sections print in order as each renders whole; a failure
# prints one line through saw_fail and returns non-zero, keeping everything
# already printed. run_active_work() swallows that so the dispatcher continues.
saw_main() {
  if [ -z "${WORK_DIR:-}" ]; then
    saw_fail 'no work directory - lib.sh must be sourced and initialised first'
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    saw_fail 'python3 is not on PATH'
    return 1
  fi

  saw_workspace_id=${WORKSPACE_ID:-${SPEQQ_WORKSPACE_ID:-}}
  if [ -z "$saw_workspace_id" ]; then
    saw_fail 'no workspace id was resolved before this step'
    return 1
  fi

  # 1. queue_read — the open work, and the branch -> spec mapping.
  saw_args=$(python3 -c "$SAW_PYTHON" queue-args "$saw_workspace_id" 2>/dev/null) || {
    saw_fail 'could not build the queue_read arguments'
    return 1
  }
  saw_call queue_read "$saw_args" || return 1
  parse_response structured queue_read >"$WORK_DIR/saw-queue" || {
    saw_fail "could not read the queue: $(parse_error_line)"
    return 1
  }

  # 2. The open-work section, buffered whole then printed.
  if ! python3 -c "$SAW_PYTHON" render-queue "$SAW_MAX_OPEN_ITEMS" <"$WORK_DIR/saw-queue" >"$WORK_DIR/saw-open" 2>"$WORK_DIR/saw-error"; then
    saw_fail "could not render the open work: $(saw_error_line)"
    return 1
  fi
  cat "$WORK_DIR/saw-open"

  # 3. The active item: exact branch match -> linked spec, or a named miss.
  saw_active=$(python3 -c "$SAW_PYTHON" active-spec "$(saw_current_branch)" <"$WORK_DIR/saw-queue" 2>"$WORK_DIR/saw-error") || {
    saw_fail "could not resolve the active spec: $(saw_error_line)"
    return 1
  }
  if [ "$(printf '%s\n' "$saw_active" | cut -f 1)" != 'hit' ]; then
    printf '%s\n' "$saw_active" | cut -f 2-
    return 0
  fi
  saw_spec_id=$(printf '%s\n' "$saw_active" | cut -f 2)
  saw_title=$(printf '%s\n' "$saw_active" | cut -f 3-)
  [ -n "$saw_title" ] || saw_title=$saw_spec_id

  # 4. spec_memory_read — the tail of the active spec's MEMORY.md, verbatim.
  saw_args=$(python3 -c "$SAW_PYTHON" memory-args "$saw_spec_id" "$SAW_MEMORY_LIMIT" 2>/dev/null) || {
    saw_fail 'could not build the spec_memory_read arguments'
    return 1
  }
  saw_call spec_memory_read "$saw_args" || return 1
  parse_response structured spec_memory_read >"$WORK_DIR/saw-memory" || {
    saw_fail "could not read the spec memory: $(parse_error_line)"
    return 1
  }
  if ! python3 -c "$SAW_PYTHON" render-memory "$saw_title" <"$WORK_DIR/saw-memory" >"$WORK_DIR/saw-tail" 2>"$WORK_DIR/saw-error"; then
    saw_fail "could not render the memory tail: $(saw_error_line)"
    return 1
  fi
  cat "$WORK_DIR/saw-tail"
}

# The identity coda: which session THIS is, so the agent reads attributed
# memory lines correctly — its own vs an earlier session's handoff. Printed
# whenever a session id is known, even when a section above failed.
saw_identity_coda() {
  saw_session=$(printf '%s' "${SPEQQ_HARNESS_SESSION_ID:-}" | cut -c 1-8)
  [ -n "$saw_session" ] || return 0
  saw_agent=${SPEQQ_HOOK_AGENT:-claude-code}
  printf 'You are session %s (%s). Memory lines carry the session that wrote them - lines from other sessions are earlier work; read them as a handoff, not your own memory.\n' \
    "$saw_session" "$saw_agent"
}

# Contract entry point: the dispatcher calls this and must always continue.
run_active_work() {
  saw_main || :
  saw_identity_coda
  return 0
}
