---
name: add-to-queue
description: Add an item to the workspace queue. Use it to capture or log a task with a title and a short note so it's tracked, without writing a full spec. Triggers on "add to the queue", "log a task", "track this", "note to do", or "backlog item".
---

# Add to the queue

Add one item to the workspace queue: a title and a short note, so the work is tracked without a full spec. Use it to capture something quickly and come back to it later.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.

## Steps

1. **Resolve the workspace.** Call `list_workspaces`. If there's one, use it. If there are several, ask which.
2. **Get the item.** Take a short title from the user. Ask for a one-line note if the intent is unclear. Keep it brief. This is a capture, not a spec.
3. **Add it.** Call `queue_add` with the workspace, the title, and the note as the description.
4. **Set priority if the user gave one.** Call `queue_update_item` with the row and the priority label, for example `P1: High`. Skip this step if they didn't ask.
5. **Report.** Say what was added and its priority.

## FYI

- This is a capture, not a spec. Don't write an overview, requirements, or tabs.
- One item per run. To add several, run it once for each.
- To write a full spec for a queued item later, use `scope-spec` or `write-spec`.
