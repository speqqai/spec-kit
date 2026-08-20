---
name: add-memory
description: Append a note to a spec's memory, the running log of what happened during its work. Use when the user says to record, note, remember, log, or jot down where the work stands, a decision, a finding, or anything worth keeping for whoever picks the spec up next.
---

# Add memory

Every spec keeps a memory: a running log of what happened while it was worked, in the order it happened. Read top to bottom, it tells the whole story of the feature, so a later session can pick the work up instead of reconstructing it from the code and the commits. This skill adds one note to that log on demand.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.
- A spec to write to.

## Steps

1. **Resolve the spec.** Use the queue item, the spec the user named, or the current branch through `spec_orient`. If nothing resolves, ask. A note on the wrong spec is a line nobody can trace.
2. **Decide what to record.** Record what the user asked for. If the request is vague, such as "note where we are", write it from what happened this session and show it before you append. Don't invent something that didn't happen to fill the entry.
3. **Write the entry.** Call `spec_memory_append` with the text. The server stamps the time.
4. **Confirm.** Report the stamped entry so the user sees what landed.

## FYI

- An entry is a short paragraph, not one line and not a list. Two to four sentences: what happened and why it mattered, short enough to scan.
- Open with a past-tense verb that names the event, so the log reads as a timeline: **Started**, **Built**, **Committed**, **Proved**, **Decided**, **Found**, **Fixed**, **Dropped**, **Blocked**, **Paused**, **Done**. A Paused or Done entry usually ends by naming the next step.
- Say why when the why is the point. An abandoned approach recorded without its reason invites the next session to try it again.
- Name the thing. "Dropped the webhook handler" carries more than "dropped that approach".
- One event per entry. If it needs an "and", append twice.
- The memory is append-only. A correction is a new entry that says what changed, not a rewrite of the old one.
