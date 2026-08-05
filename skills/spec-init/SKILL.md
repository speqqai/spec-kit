---
name: spec-init
description: >-
  Set a new piece of work up properly in one act — creates the spec shell,
  files the matching queue item, links the two, sets priority, and flips the
  item to in progress. Use when a user wants to start something new, spin up a
  spec, add work to the queue, or "get this going". Creates scaffolding only:
  the spec's content is written by spec-product and the rest of the discipline
  skills.
---

# spec-init

Stands up the scaffolding for a new piece of work so nothing is half-created.

Setup is ONE ACT, not four things to remember. A spec with no queue item is
invisible to whoever picks work up next; a queue item with no spec is a title
with nowhere to write. Doing them separately is how one gets forgotten — which
is exactly why this skill exists.

## Preflight

Speqq MCP must be connected: `list_workspaces`, `spec_create`, `queue_add`,
`queue_attach_document`, `queue_update_item`. If the tools are not available,
STOP and walk the user through connecting the Speqq MCP server for their
harness. Never fall back to local files, and never create a spec on disk.

## Steps

Run these in order, waiting for each to return. A failure part-way leaves
scaffolding half-built, so report exactly what exists before stopping.

1. **Resolve the workspace.** `list_workspaces` — one, use it; several, ask.
2. **Settle the title with the user.** Commit form: `feat: <feature>`,
   `feat(scope): <feature>`, or `fix(scope): <defect>`. The queue item takes the
   same title, so they stay findable together. Confirm before creating anything —
   a renamed spec leaves a stale queue title behind.
3. **Create the spec shell.** `spec_create` with the workspace and title. Keep
   the returned `spec_id`. It has no tabs yet, and that is correct: this skill
   creates scaffolding, not content.
4. **File the queue item.** `queue_add` with the workspace, the same title, and
   a one-line description of the intent. Keep the returned queue `row_id`.
5. **Link them.** `queue_attach_document` with the queue `row_id` and the spec
   as `source_document_id` — note the parameter name; it is not
   `document_id`. This is the link that lets any later session resolve the spec
   from the queue item alone.
6. **Set status and priority.** `queue_update_item` with `status`
   `in_progress` and the priority the user chose, as the workspace's visible
   label (for example `P1: High`). Ask for the priority rather than assuming one.
7. **Report what exists.** The spec title and id, the queue item and its status,
   and that the link is in place. Then say what comes next: `spec-research` to
   get up to speed, or `spec-product` to write the Overview and Requirements.

## Assignment has no MCP write

The user will often ask for the work to be assigned to them. **There is no MCP
tool that sets an assignee** — neither `cell_set` nor `queue_update_item`
accepts one. Do not claim it was assigned, and do not invent a field.

Say so plainly and offer the two honest options: they assign it in the Speqq app
in one click, or the intended owner goes in the queue item's description as an
interim. Label the interim as one so the gap stays visible.

## Worth being careful about

- **Do not write spec content here.** No Overview, no Requirements, no tabs. A
  shell with invented content is worse than an empty one, because the next skill
  treats it as intent.
- **Do not create the branch.** `spec-implement` creates it from the spec title
  and links it onto the rows it delivers.
- **Never create a duplicate.** If a spec with this title already exists,
  `spec_list` will show it — reuse it and file only what is missing.
