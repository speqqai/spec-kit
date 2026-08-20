---
name: pause-work
description: Stop work on a spec cleanly. Writes one entry to the spec's memory describing exactly where the work stands and what comes next, and brings the spec's row statuses in line with reality, so the next session can pick the work up instead of reconstructing it. Use when a user says to pause, stop, wrap up, take a break, or that they are done for now, or before any run that is about to be interrupted.
---

# Pause work

End a session so the next one starts from a record rather than from commits. An agent's context can end at any moment, and anything not written down is gone; this skill is the deliberate ending, the one where you write the record first.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.
- A spec to pause.

## Steps

1. **Resolve the spec.** Resolve it as `start-work` does: a queue item, a spec the user named, or the current branch via `spec_orient`. If nothing resolves, ask rather than guess. A pause note on the wrong spec is worse than none.
2. **Take stock before writing.** Read what actually happened this session: `git status` and the commits on this branch, the spec's rows and their statuses, and `spec_memory_read` for what was already recorded. The note describes the state, so it has to be the real one.
3. **Bring the rows in line.** `cell_set` the status of any row whose reality has moved: `done` only where the behaviour is observable, `in_progress` for started-and-unfinished. Never flip a row to `done` to make a session look tidy. An inaccurate ledger costs the next agent more than an untidy one.
4. **Write the pause note.** One `spec_memory_append` covering three things in plain sentences:
   - **What landed:** the behaviour that now works, not the files touched.
   - **What did not:** including anything tried and abandoned, with the reason. This is the most valuable part of the note and the part most often left out.
   - **What is next:** the specific next step, not "continue".
   It runs longer than an ordinary entry because it describes a state rather than an event, but it is still one entry with no special form: it reads as a pause because of what it says.
5. **Queue and report.** If a queue item drove the run, leave its status honest: `in_progress` if the work is unfinished; propose `done` only if it genuinely is, and apply on a yes. Then report to the user what you recorded.

## FYI

- A good pause note can be acted on by someone who was not here: *"Paused here. Ledger and retries are in; the dead-letter path and the poison-message test are not. Dropped the webhook approach: retry semantics could not be made idempotent. Next is the dead-letter path. 3 of 7 requirements left."* "Paused work on retries" cannot be acted on by anyone.
- Write the note even when the session achieved nothing. "Spent the session trying X; it does not work because Y" is a full session's value preserved.
- Never edit an earlier entry to tidy the story. The memory is append-only and the tools refuse it; the log is a record, not a summary.
- Do not skip this because the work is unfinished. Unfinished work is precisely what a pause note is for.
