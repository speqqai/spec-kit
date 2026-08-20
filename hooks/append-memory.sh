#!/bin/sh
#
# append-memory.sh — the checkpoint ladder (adapted from append-spec-memory.sh),
# MINUS the near-empty rung that read-product-context.sh and read-memory.sh now
# own. As the context window fills, tell the LIVE agent to record where the
# work stands in the active spec's memory — once per filling rung, once each
# per window. The final rung, just under auto-compaction, says to save now
# while full context remains. The memory log ends up reading as a chronological
# story of the session, written by the agent itself.
#
# The rung math and the instruction wording are preserved from the original
# ladder: the highest unfired rung at or below the current fill fires once, a
# jump past two rungs nudges once for the highest, and a fill overshooting the
# assumed default window parks the ladder and names SPEQQ_CONTEXT_WINDOW as the
# fix (all in lib.sh's engine). The per-window flag re-arms by capacity when a
# compaction drops the fill (also in lib.sh).
#
# Tokenless: this hook opens no MCP connection, resolves no credentials, and
# makes no network call. It only measures the local transcript (in lib.sh) and
# prints an instruction for the agent to act on over its OWN MCP connection.
# Every path exits 0; stdout carries the injection only when a rung fires.
#
# Env: SPEQQ_CONTEXT_NUDGE_PCT (comma list of filling rungs, default
# "25,50,75,95"), SPEQQ_HOOK_AGENT (attribution name), SPEQQ_WORKSPACE_ID
# (optional, sharpens the queue lookup), plus the shared SPEQQ_CONTEXT_WINDOW.

set -u

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 0
[ -f "$SCRIPT_DIR/lib.sh" ] || exit 0
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

AM_RUNGS=${SPEQQ_CONTEXT_NUDGE_PCT:-25,50,75,95}
AM_AGENT=${SPEQQ_HOOK_AGENT:-claude-code}

AM_BRANCH=$(git branch --show-current 2>/dev/null) || AM_BRANCH=''
if [ -n "$AM_BRANCH" ]; then
  AM_WHERE="$AM_BRANCH"
else
  AM_WHERE="the current branch"
fi

# The workspace id, when set in the environment — a non-secret that sharpens
# the queue lookup line. No credentials file is read: the hooks are tokenless.
AM_WORKSPACE=${SPEQQ_WORKSPACE_ID:-}
if [ -n "$AM_WORKSPACE" ]; then
  AM_LOOKUP="queue_read in workspace $AM_WORKSPACE lists the queue"
else
  AM_LOOKUP="list_workspaces then queue_read list the queue"
fi

AM_BODY="first find the queue item whose branch is $AM_WHERE ($AM_LOOKUP), then take that item’s linked_document_id - that is the active spec - and call spec_memory_append on it with agent \"$AM_AGENT\", session_id \"{session}\", and one entry of 2-4 sentences leading with a past-tense verb (Built, Committed <hash>, Proved, Decided, Dropped, Blocked): what happened since the last entry, why, the current state (what works, what is unfinished), and the immediate next step - so the memory reads top to bottom as the story of the work. Then continue the task. If no queue item claims this branch, or the Speqq queue or spec_memory_append tools are not available in this session, skip the update and continue."

AM_OPEN_NORMAL="Checkpoint: your context window is {pct}% full. Record a progress update so the memory log tells the story of this session: "
AM_OPEN_FINAL="Your context window is {pct}% full and will be auto-compacted soon. Save your working state now, while you still have full context: "

AM_TEMPLATE="$AM_OPEN_NORMAL$AM_BODY"
AM_TEMPLATE_FINAL="$AM_OPEN_FINAL$AM_BODY"

speqq_run ladder append-ladder "$AM_RUNGS" "$AM_TEMPLATE" "$AM_TEMPLATE_FINAL"
