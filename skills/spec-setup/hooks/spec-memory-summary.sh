# shellcheck shell=sh
#
# spec-memory-summary.sh — the post-compaction step: tell the AGENT to write
# a real summary to spec memory. Sourced by session-start.sh; runs only when
# the session source is `compact`.
#
# Why an instruction and not a script: a shell hook can record facts (branch,
# dirty files — spec-memory.sh does), but only the model can summarize what
# the work MEANS. Right after compaction the agent still holds the compaction
# summary and its MCP tools, so this step injects one direct instruction and
# the agent writes the entry another agent can actually resume from.
#
# stdout here IS the injection — that is the point of this step. It runs in
# both dispatcher modes: the tools it names are the AGENT's own MCP tools,
# not the hook's, so it needs no hook credentials — and its final clause
# already covers the session where those tools turn out to be absent.

case ${0##*/} in
spec-memory-summary.sh)
  printf 'speqq session-start: spec-memory-summary.sh is a step library - run session-start.sh instead\n' >&2
  exit 0
  ;;
esac

run_memory_summary() {
  sms_branch=$(git branch --show-current 2>/dev/null) || sms_branch=''
  sms_agent=${SPEQQ_HOOK_AGENT:-claude-code}
  sms_session=${SPEQQ_HARNESS_SESSION_ID:-}
  sms_transcript=${SPEQQ_TRANSCRIPT_PATH:-}

  sms_workspace=${WORKSPACE_ID:-}
  if [ -n "$sms_workspace" ]; then
    sms_lookup="queue_read in workspace $sms_workspace lists the queue"
  else
    sms_lookup="list_workspaces then queue_read list the queue"
  fi

  cat <<INSTRUCTION

Your context was just compacted. Before continuing the task, record where the
work stands so the next session (or another agent) can resume from it:
1. Find the queue item whose branch is ${sms_branch:-"the current checkout branch"}
   ($sms_lookup).
2. Take that item's linked_document_id - that is the active spec - and call
   spec_memory_append on it with agent "$sms_agent"${sms_session:+, session_id "$sms_session"},
   and 2-4 sentences in your own words: what you were doing, the current
   state (what works, what is unfinished), and the immediate next step.
3. Then continue the task you were on.
If no queue item claims this branch, or the Speqq queue or spec_memory_append
tools are not available in this session, skip the update and continue.${sms_transcript:+
Compaction compressed your window, not the record: the complete pre-compaction
conversation is preserved at $sms_transcript
- Read its tail first if the compacted summary is missing details you need.}
INSTRUCTION
}
