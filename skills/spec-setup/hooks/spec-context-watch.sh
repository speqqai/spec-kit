#!/bin/sh
#
# spec-context-watch.sh — the checkpoint ladder: as the context window fills,
# tell the LIVE agent to record where the work stands — once near the start
# of the window, once in the middle, and once right before auto-compaction
# would fire. PostToolUse runs this after every tool call; between rungs it
# exits instantly and silently. The memory log ends up reading as a
# chronological story of the session, written by the agent itself.
#
# Why this exists: PreCompact hooks cannot put text in front of the model
# (their output never reaches it), and model-in-the-loop compaction hooks
# were declined upstream. But PostToolUse supports additionalContext —
# the agent reads the reminder on its next request — and every hook
# receives transcript_path. So the fill level is measurable and the nudge is
# injectable while the agent still has its FULL context: the one moment a
# real pre-compact summary can be written by the one writer that can write
# it.
#
# Two transcript shapes are read, and a record identifies its own shape —
# no harness flag decides the parse:
#   - Claude Code JSONL: assistant records carrying message.usage
#     (input_tokens + cache_creation_input_tokens + cache_read_input_tokens).
#   - Codex rollouts: event_msg records carrying payload.type "token_count",
#     whose info.last_token_usage.input_tokens is the last request's prompt
#     size and whose info.model_context_window names the window itself.
# A transcript that yields neither is a silent skip — a harness this script
# does not know is not an error.
#
# Discipline for a hook that fires constantly:
#   - No network. No credentials. One python3 pass over the transcript TAIL.
#   - Silent below threshold: stdout empty, stderr empty, exit 0.
#   - Never silent about real trouble: a runtime failure prints ONE stderr
#     line naming the cause, and still exits 0.
#   - Each rung fires ONCE per window: a session-keyed flag file records the
#     highest rung fired, and the session-start dispatcher clears it on the
#     post-compaction firing so the next window climbs the ladder again.
#   - Never blocks anything: every path exits 0.
#
# Env: SPEQQ_CONTEXT_NUDGE_PCT (comma list of rungs, default "1,10,25,50,75,95"),
# SPEQQ_CONTEXT_WINDOW (overrides everything; default is the transcript's
# own window when it names one, else 200000), SPEQQ_HOOK_AGENT (attribution
# name for the instruction). A fill that overshoots the assumed default
# proves the default wrong for this model: the ladder parks for the window
# and names SPEQQ_CONTEXT_WINDOW as the fix, once, on stderr.

set -u

SM_NUDGE_PCT=${SPEQQ_CONTEXT_NUDGE_PCT:-1,10,25,50,75,95}
SM_WINDOW=${SPEQQ_CONTEXT_WINDOW:-}
SM_AGENT=${SPEQQ_HOOK_AGENT:-claude-code}
SM_BRANCH=$(git branch --show-current 2>/dev/null) || SM_BRANCH=''
# The workspace id, when discoverable without a network call: the env wins,
# else the one non-secret line of the credentials file. The token itself is
# never read into a variable.
SM_WORKSPACE=${SPEQQ_WORKSPACE_ID:-}
if [ -z "$SM_WORKSPACE" ]; then
  SM_CREDS=${SPEQQ_CREDENTIALS_FILE:-$HOME/.speqq/credentials}
  [ -f "$SM_CREDS" ] && SM_WORKSPACE=$(sed -n 's/^SPEQQ_WORKSPACE_ID=//p' "$SM_CREDS" | tail -n 1 | tr -d '\r')
fi

command -v python3 >/dev/null 2>&1 || exit 0

# Double quotes only inside — the string is single-quoted shell.
SM_WATCH_PYTHON='
import json
import os
import re
import sys
import tempfile

DEFAULT_WINDOW = 200000


def usage_from_claude(entry):
    """Claude Code JSONL: the assistant record carries message.usage; the
    window fill is the last request prompt (fresh + cache writes + cache
    reads)."""
    if entry.get("type") != "assistant":
        return None
    message = entry.get("message")
    usage = message.get("usage") if isinstance(message, dict) else None
    if not isinstance(usage, dict):
        return None
    used = (
        int(usage.get("input_tokens", 0) or 0)
        + int(usage.get("cache_creation_input_tokens", 0) or 0)
        + int(usage.get("cache_read_input_tokens", 0) or 0)
    )
    return (used, 0)


def usage_from_codex(entry):
    """Codex rollout: event_msg records with payload.type token_count carry
    info.last_token_usage (the last request, prompt side already inclusive
    of cached tokens) and info.model_context_window (the window itself)."""
    payload = entry.get("payload")
    if not isinstance(payload, dict) or payload.get("type") != "token_count":
        return None
    info = payload.get("info")
    if not isinstance(info, dict):
        return None
    last = info.get("last_token_usage")
    if not isinstance(last, dict):
        return None
    used = int(last.get("input_tokens", 0) or 0)
    if used <= 0:
        return None
    window = info.get("model_context_window")
    window = int(window) if isinstance(window, (int, float)) and int(window) > 0 else 0
    return (used, window)


def run():
    RUNGS = sorted(float(p) for p in sys.argv[1].split(",") if p.strip())
    ENV_WINDOW = int(sys.argv[2]) if sys.argv[2].strip().isdigit() else 0
    AGENT, BRANCH = sys.argv[3], sys.argv[4]
    WORKSPACE = sys.argv[5] if len(sys.argv) > 5 else ""
    if not RUNGS:
        raise SystemExit(0)

    raw = "" if sys.stdin.isatty() else sys.stdin.read()
    try:
        payload = json.loads(raw)
    except ValueError:
        raise SystemExit(0)
    if not isinstance(payload, dict):
        raise SystemExit(0)

    session = payload.get("session_id", "")
    transcript = payload.get("transcript_path", "")
    if not isinstance(session, str) or not re.fullmatch(r"[A-Za-z0-9._-]{1,128}", session):
        raise SystemExit(0)
    if not isinstance(transcript, str) or not os.path.isfile(transcript):
        raise SystemExit(0)

    # Each rung fires once per window: the flag holds the highest rung fired;
    # session-start.sh removes the flag on the post-compaction firing so the
    # next window climbs the ladder again.
    flag = os.path.join(tempfile.gettempdir(), "speqq-context-nudge-" + session)
    fired = -1.0
    if os.path.exists(flag):
        try:
            fired = float(open(flag).read().strip() or "-1")
        except (OSError, ValueError):
            fired = -1.0

    # The LAST record carrying usage tells the current window fill. Tail
    # only: long transcripts are huge and this runs after every tool call.
    TAIL_BYTES = 262144
    with open(transcript, "rb") as handle:
        handle.seek(0, 2)
        handle.seek(max(0, handle.tell() - TAIL_BYTES))
        lines = handle.read().decode("utf-8", "replace").splitlines()

    used = None
    record_window = 0
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if not isinstance(entry, dict):
            continue
        hit = usage_from_claude(entry) or usage_from_codex(entry)
        if hit:
            used, record_window = hit
            break

    if used is None:
        raise SystemExit(0)
    window = ENV_WINDOW or record_window or DEFAULT_WINDOW
    pct = used * 100.0 / window
    # The highest unfired rung at or below the current fill. A jump past two
    # rungs nudges once, for the highest.
    due = [r for r in RUNGS if r > fired and pct >= r]
    if not due:
        raise SystemExit(0)
    if pct > 100 and not (ENV_WINDOW or record_window):
        # A fill above 100% against the assumed default proves the default
        # window is wrong for this model (Claude transcripts never name
        # theirs). Guessing a bigger window would guess the nudge points
        # too - park the ladder for this window and say so once; the flag
        # keeps the line from repeating on every tool call.
        with open(flag, "w") as handle:
            handle.write("%.1f" % max(RUNGS))
        sys.stderr.write(
            "speqq context-watch: measured %d tokens against the assumed %d-token window - "
            "set SPEQQ_CONTEXT_WINDOW to the real model window; nudges are parked for this window\n"
            % (used, window)
        )
        raise SystemExit(0)
    rung = max(due)
    final = rung == max(RUNGS)

    # Record the rung BEFORE emitting, so a crash after this line costs one
    # nudge, never a nudge storm.
    with open(flag, "w") as handle:
        handle.write("%.1f" % rung)

    where = BRANCH if BRANCH else "the current branch"
    if WORKSPACE:
        lookup = "queue_read in workspace %s lists the queue" % WORKSPACE
    else:
        lookup = "list_workspaces then queue_read list the queue"
    if final:
        opening = (
            "Your context window is %.0f%% full and will be auto-compacted soon. "
            "Save your working state now, while you still have full context: " % pct
        )
    else:
        opening = (
            "Checkpoint: your context window is %.0f%% full. Record a progress "
            "update so the memory log tells the story of this session: " % pct
        )
    instruction = opening + (
        "first find the queue item whose branch is %s (%s), then take that item"
        "\u2019s linked_document_id - that is the active spec - and call "
        "spec_memory_append on it with agent \"%s\", session_id \"%s\", and one "
        "entry of 2-4 sentences leading with a past-tense verb (Built, Committed "
        "<hash>, Proved, Decided, Dropped, Blocked): what happened since the last "
        "entry, why, the current state (what works, what is unfinished), and the "
        "immediate next step - so the memory reads top to bottom as the story of "
        "the work. Then continue the task. If no queue item claims this branch, "
        "or the Speqq queue or spec_memory_append tools are not available in this "
        "session, skip the update and continue." % (where, lookup, AGENT, session)
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": instruction,
                }
            }
        )
    )


try:
    run()
except SystemExit:
    raise
except Exception as error:
    sys.stderr.write("speqq context-watch: " + str(error).replace("\n", " ") + "\n")
    raise SystemExit(0)
'

python3 -c "$SM_WATCH_PYTHON" "$SM_NUDGE_PCT" "$SM_WINDOW" "$SM_AGENT" "$SM_BRANCH" "$SM_WORKSPACE" || :
exit 0
