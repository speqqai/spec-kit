---
name: spec-start
description: >-
  Begin work on a spec. Resolves the spec, reads PRODUCT.md and the spec's plan,
  opens its MEMORY.md with a first snippet recording that work started and what
  the goal is, and marks the queue item in progress. Use when a user says they
  are starting a spec, picking up a queued feature, or beginning work on a
  branch that has none recorded yet. For returning to work already underway,
  use spec-resume instead — it reads the memory rather than opening one.
---

# spec-start

Opens a session on a spec: what it is, what the product is, and a first line in
the memory so a later session knows this run happened at all.

The memory a spec keeps is append-only and written by agents. It exists because
a context window ends — sometimes deliberately, sometimes not — and everything
not recorded is lost with it. `spec-start` writes the first line.

## Steps

1. **Resolve the workspace.** `list_workspaces` — one, use it; several, ask.
2. **Resolve the spec.** In order, stopping at the first that answers: a queue
   item the user picked (`queue_read` → its `linked_document_id`); a spec the
   user named (`spec_list`, filter titles client-side); the current git branch
   (`git branch --show-current`, then `spec_orient` with it). If nothing
   resolves, show a short `spec_list` overview and ask.
3. **Check it is not already underway.** `spec_memory_read` the spec. **If it
   returns snippets, stop and switch to spec-resume** — this spec has been
   worked, and starting it again would write a beginning over a middle. Say so
   plainly rather than appending anyway.
4. **Read what you are building.** `spec_orient` returns a `product_file`
   pointer when the workspace has a PRODUCT.md; `spec_read` it. It carries what
   the product is, who it is for, and what must never break — the things the
   code cannot tell you. Then `spec_read` the spec's Requirements and
   Implementation plan.
5. **Record the start.** One `spec_memory_append` naming what this run is going
   after — not "started work", which says nothing a timestamp does not. Name the
   goal: *Starting on the retry path: failed writes must survive a restart.*
6. **Mark it in progress.** If the run came from a queue item,
   `queue_update_item` its status to `in_progress`.
7. **Report.** The spec, what it is for, what is open, and what you intend to do
   first. Then hand over to spec-implement, or to the user.

## Worth being careful about

- **Do not start a spec that is already underway.** Step 3 exists because the
  memory is a log, and a second beginning in the middle of one misleads every
  later reader.
- **The memory is created by the first append.** There is nothing to set up: if
  the spec has no memory, appending makes one.
- **Nothing else writes here.** No local notes file, no scratch markdown, no
  progress file on the user's machine. The spec and its memory are the record.
