#!/bin/sh
#
# spec-context-watch.sh — the pre-compaction nudge: when the context window
# crosses a fill threshold, tell the LIVE agent to save its working state to
# spec memory BEFORE auto-compaction fires. PostToolUse runs this after every
# tool call; below the threshold it exits instantly and silently.
#
# Why this exists: PreCompact hooks cannot put text in front of the model
# (their output never reaches it), and model-in-the-loop compaction hooks
# were declined upstream. But PostToolUse supports additionalContext —
# "Claude reads the reminder on the next model request" — and every hook
# receives transcript_path, whose assistant records carry message.usage. So
# the fill level is measurable and the nudge is injectable while the agent
# still has its FULL context: the one moment a real pre-compact summary can
# be written by the one writer that can write it.
#
# Discipline for a hook that fires constantly:
#   - No network. No credentials. One python3 pass over the transcript TAIL.
#   - Silent below threshold: stdout empty, stderr empty, exit 0.
#   - Nudges ONCE per approach: a session-keyed flag file arms it, and the
#     session-start dispatcher clears the flag on the post-compaction firing
#     so the next climb re-arms it.
#   - Never blocks anything: every path exits 0.
#
# Env: SPEQQ_CONTEXT_NUDGE_PCT (default 80), SPEQQ_CONTEXT_WINDOW (default
# 200000), SPEQQ_HOOK_AGENT (attribution name for the instruction).

set -u

SM_NUDGE_PCT=${SPEQQ_CONTEXT_NUDGE_PCT:-80}
SM_WINDOW=${SPEQQ_CONTEXT_WINDOW:-200000}
SM_AGENT=${SPEQQ_HOOK_AGENT:-claude-code}
SM_BRANCH=$(git branch --show-current 2>/dev/null) || SM_BRANCH=''

command -v python3 >/dev/null 2>&1 || exit 0

# Double quotes only inside — the string is single-quoted shell.
SM_WATCH_PYTHON='
import json
import os
import re
import sys
import tempfile

THRESHOLD, WINDOW = float(sys.argv[1]), int(sys.argv[2])
AGENT, BRANCH = sys.argv[3], sys.argv[4]

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

# Once per approach: the flag arms after a nudge; session-start.sh removes it
# on the post-compaction firing so the next climb nudges again.
flag = os.path.join(tempfile.gettempdir(), "speqq-context-nudge-" + session)
if os.path.exists(flag):
    raise SystemExit(0)

# The LAST assistant record carries the current window fill. Tail only: long
# transcripts are huge and this runs after every tool call.
TAIL_BYTES = 262144
with open(transcript, "rb") as handle:
    handle.seek(0, 2)
    handle.seek(max(0, handle.tell() - TAIL_BYTES))
    lines = handle.read().decode("utf-8", "replace").splitlines()

used = None
for line in reversed(lines):
    try:
        entry = json.loads(line)
    except ValueError:
        continue
    if not isinstance(entry, dict) or entry.get("type") != "assistant":
        continue
    message = entry.get("message")
    usage = message.get("usage") if isinstance(message, dict) else None
    if not isinstance(usage, dict):
        continue
    used = (
        int(usage.get("input_tokens", 0) or 0)
        + int(usage.get("cache_creation_input_tokens", 0) or 0)
        + int(usage.get("cache_read_input_tokens", 0) or 0)
    )
    break

if used is None:
    raise SystemExit(0)
pct = used * 100.0 / WINDOW
if pct < THRESHOLD:
    raise SystemExit(0)

# Arm the flag BEFORE emitting, so a crash after this line costs one nudge,
# never a nudge storm.
with open(flag, "w") as handle:
    handle.write("%.1f" % pct)

where = BRANCH if BRANCH else "the current branch"
instruction = (
    "Your context window is %.0f%% full and will be auto-compacted soon. "
    "Before continuing, save your working state while you still have full context: "
    "resolve the active spec (the queue item whose branch is %s - queue_read shows "
    "each item, its branch, and its linked spec) and call spec_memory_append on it "
    "with agent \"%s\", session_id \"%s\", and 2-4 sentences in your own words: what "
    "you are doing, the current state (what works, what is unfinished), and the "
    "immediate next step. Then continue the task. If no queue item claims this "
    "branch, skip the append and continue." % (pct, where, AGENT, session)
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
'

python3 -c "$SM_WATCH_PYTHON" "$SM_NUDGE_PCT" "$SM_WINDOW" "$SM_AGENT" "$SM_BRANCH" 2>/dev/null || :
exit 0
