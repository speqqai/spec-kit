---
name: start-work
description: Begin work on a spec. Reads the product brief and the spec's plan, opens the spec's memory with a first entry recording that work started and the goal, and marks the queue item in progress. Use when a user says they are starting a spec, picking up a queued feature, or beginning work on a branch that has nothing recorded yet. To return to work already underway, use resume-work instead, which reads the memory rather than opening one.
---

# Start work

Open a session on a spec: resolve what it is, read the product brief and the plan, and write the first entry in the spec's memory so a later session knows this run happened at all. The memory is append-only and written by agents; a context window can end at any moment, and everything not recorded is lost with it.

When the repository root contains `.speqq` with `memory: @handle`, also call Knowledge MCP `memory_read` with that handle (without `@`) and the workspace ID before planning. Its cited summary and durable entries provide the team's shared context. The spec's own memory remains the record of this spec's work.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.
- A spec, a queued item, or a branch to start work on.

## Steps

1. **Resolve the workspace.** Call `list_workspaces`. One workspace, use it. Several, ask which.
2. **Resolve the spec.** In order, stopping at the first that answers: a queue item the user picked (`queue_read`, then its `linked_document_id`); a spec the user named (`spec_list`, filter titles); the current git branch (`git branch --show-current`, then `spec_orient` with it). If nothing resolves, show a short `spec_list` overview and ask.
3. **Check it is not already underway.** Call `spec_memory_read`. If it returns entries, stop and switch to `resume-work`. This spec has been worked, and starting it again writes a beginning over a middle. Say so plainly rather than appending anyway.
4. **Read what you are building.** Call `get_context` for product context when available, then `spec_read` the spec's Page and Table, including the requirement rows and child build steps. Do not expect a `product_file` field from `spec_orient`.
5. **Record the start.** One `spec_memory_append` naming what this run is going after. Not "started work", which says nothing a timestamp does not. Name the goal: *Starting on the retry path: failed writes must survive a restart.*
6. **Mark it in progress.** If the run came from a queue item, set its status to `in_progress` with `queue_update_item`.
7. **Report.** The spec, what it is for, what is open, and what you intend to do first. Then hand over to `implement-spec`, or to the user.

## FYI

- Do not start a spec that is already underway. Step 3 exists because the memory is a log, and a second beginning in the middle of one misleads every later reader.
- The memory is created by the first append. There is nothing to set up: if the spec has no memory, appending makes one.
- Nothing else writes here. No local notes file, no scratch markdown, no progress file on the user's machine. The spec and its memory are the record.
