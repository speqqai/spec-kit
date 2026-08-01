---
name: spec-queue
description: File a spec's planned work into the Speqq workspace queue as deduplicated, traceable queue items — the Speqq replacement for converting a plan's tasks into GitHub issues. Use when a user wants to queue a spec's implementation work, push plan steps into the workspace queue, or re-run filing after the plan changes. Reads the spec's Implementation plan, skips work the queue already represents, and creates the rest with priority labels and the spec id embedded for traceability.
---

# spec-queue

Files the active spec's planned work into the Speqq workspace queue, one queue
item per plan step that the queue does not already represent. This is the
tasks-to-issues discipline from spec-driven development aimed at Speqq: the
workspace queue is the issue tracker — dedup first, checkpoint with the user,
then create. spec-implement later picks work up from these items.

Everything this skill produces lands in the Speqq queue over MCP. It creates
queue items only: it never rewrites the spec, never touches unmatched existing
queue items, and never writes a file to the user's machine.

## Preflight

1. **Speqq MCP must be connected.** If the Speqq MCP tools (`list_workspaces`,
   `spec_list`, `spec_read`, `queue_read`, `queue_add`, ...) are not
   available, STOP before doing anything else. Tell the user this skill
   writes only to Speqq and walk them through connecting the Speqq MCP server
   for their harness. Never fail silently, and never fall back to local files
   or another tracker.
2. **Resolve the workspace.** Call `list_workspaces` before any other Speqq
   call. One workspace: use it. Several: ask the user which. Keep the
   `workspace_id` for every subsequent call.
3. **Zero local state.** Never create or modify any file on the user's
   machine — no pointer files, no notes files, no exported task lists.
   Candidate lists, dedup tables, and drafts live in conversation context
   only. (Git operations that ARE implementation work — branching, committing
   code — belong to spec-implement, not here; this skill performs none.)

## Finding the spec

Resolve the active spec in exactly this order. Stop at the first rung that
yields one spec. Never consult or create a local pointer file.

1. **A queue item the user picked.** If the user pointed at a queue item, its
   `linked_document_id` is the spec. Items this skill filed earlier carry the
   spec id embedded in their description instead — accept either.
2. **The spec the user names.** `spec_list` the workspace and filter titles
   client-side for the name the user gave. There is no spec search over MCP.
3. **The current git branch.** Read the branch name (`git branch
   --show-current` — a read, not state). No by-branch lookup exists over MCP
   yet, so the interim is a bounded scan: `spec_list`, filter client-side to
   specs with status `building` (falling back to the most recently updated
   few), then `spec_read` each candidate's table tabs and compare row
   `branch` values against the checked-out branch. Cap the scan at a handful
   of specs; this rung is interim pending the R2 find-by-branch lookup.
4. **Specs with status `building`.** Exactly one building spec: use it.
   Several: list them and ask.
5. **Ask.** Present a short workspace overview — a few recent specs with
   title and status from `spec_list` — and let the user choose.

## Flow: ground, then propose, then file

Only the File phase writes anything.

### Phase 1 — Ground

- `spec_read` the spec outline, then its **Implementation plan** tab — the
  ordered steps are the work to file. Read the **Requirements** table too:
  requirement priorities inform item priorities, and requirement titles help
  phrase items. If the spec has no Implementation plan, STOP and direct the
  user to spec-eng — this skill files planned work; it does not invent a plan
  from requirements.
- `queue_read` the workspace queue once. **Warning: `queue_read` returns the
  full queue — top-level items, unscheduled items, and sprint groups — and
  can be very large on big workspaces.** Scoped queue reads are a pending R2
  requirement; until then read once, keep only what dedup needs (per item:
  id, title, description, status, priority, `linked_document_id`), and filter
  in context. Do not call it repeatedly.
- Note the priority labels existing queue items actually use (for example
  `P1: High`) so new items match the workspace's conventions.
- Optionally call `get_context` for the workspace ProductContext as
  grounding for phrasing; if none exists, continue without it.

Exit: you hold the plan steps, the full queue snapshot, and the workspace's
priority label conventions — all in context.

### Phase 2 — Propose

Build the candidate list, dedup it, and checkpoint with the user.

**Candidates.** One queue item per plan step, in plan order. Title in commit
form, prefixed like the plan step (see Queue item format). Skip steps the
plan itself marks done or cancelled.

**Dedup.** For each candidate, scan the queue snapshot from Ground:

- **Represented — skip.** An existing item's description embeds this spec's
  id (or its `linked_document_id` is this spec) AND its normalized title
  matches the candidate's. Normalize both sides: lowercase, strip the
  commit-type prefix (`feat:`, `fix(scope):`, ...), strip punctuation,
  collapse whitespace.
- **Probable duplicate — skip, flag for override.** Normalized titles match
  but the item carries no spec id. List it at the checkpoint as a probable
  duplicate the user may override.
- **No match — create.**

An item's status never changes the verdict: a `done` or `cancelled` item that
represents a step still means the step is represented — do not refile it.
Never update, retitle, or remove an existing item during dedup.

**Checkpoint — mandatory, before any create.** Show the user one table:

| Plan step | Verdict | Queue item title / matched item | Priority |

with every skip's reason spelled out ("step 2 already has a queue item,
skipping"). Ask whether new items should land as `backlog` (the default for
planned work) or another status. Only after an explicit go-ahead — with any
edits folded in — does Phase 3 run. If every step is represented, report
that, create nothing, and stop.

### Phase 3 — File

For each approved candidate, in plan order, strictly sequentially:

1. `queue_add` with `workspace_id`, the commit-form `title`, and the
   traceability `description` (see Queue item format). Keep the returned
   item id — it is the `row_id` for step 2.
2. `queue_update_item` on that id to set `priority` (the visible label, e.g.
   `P1: High`) and `status` (the checkpoint's choice; queue status is
   new/backlog/todo/in_progress/done/cancelled).

Pair each `queue_add` immediately with its `queue_update_item` before
starting the next item, so an interrupted run leaves only fully-formed items.
If a call fails, stop, report exactly which items were created and which
remain, and let the user decide — a re-run is safe because dedup will skip
everything already filed.

## Queue item format

**Title** — commit form, prefixed like the plan step it files:
`feat(queue): add scoped queue reads`, `fix(editor): debounce autosave`.
One step, one item; never bundle steps.

**Description** — plain text that makes the item traceable back to the spec
with no conversation context. No spec URLs exist over MCP, so the spec id IS
the link:

```text
Spec: <spec_id> — <spec title>
Step: <plan step reference, e.g. "Implementation plan, step 3">

<one or two sentences of the step's substance, present tense>
```

The `Spec:` line is load-bearing: dedup on re-runs and rung 1 of spec
resolution both read it. Never omit or reformat it.

**Priority** — map the step's priority (or its parent requirement's) onto
the workspace's visible labels: high → `P1: High`, medium → `P2: Medium`,
low → `P3: Low`. When existing queue items show different label text, reuse
the workspace's exact labels instead.

## Writing to Speqq

Hard rules for every write, over MCP only:

- **Sequential writes.** All writes to one workspace queue or one spec are
  sequential — wait for each call to return before issuing the next.
  Parallel writes collide and silently drop.
- **Two-call creates.** `queue_add` accepts only `workspace_id`, `title`,
  and `description` — no priority, status, or linked-spec parameter. Priority
  and status always take the follow-up `queue_update_item`. A one-call
  `queue_add` with priority is a pending R2 requirement; until it lands, the
  two-call pattern is the mechanism, not an optimization to skip.
- **No spec search over MCP.** Discovery is `spec_list` plus client-side
  title/status filtering — everywhere, including spec resolution.
- **Fixed enums.** Spec status: draft/in_review/rejected/approved/queued/
  building/released — app-derived and rejected by `spec_update`; this skill never
  sets it. Row and queue status: new/backlog/todo/in_progress/done/cancelled
  (rows via `cell_set`, queue items via `queue_update_item`). Map any workflow state onto these; put
  unmappable labels in description text.
- **Patch semantics.** This skill normally writes no spec content. If a run
  ever must touch a page tab, `spec_markdown_tab_update` takes a `patches`
  array of `{old_str, new_str}` where each `old_str` occurs exactly once in
  the tab — there is no whole-document replace parameter;
  `spec_markdown_tab_append` adds to the end of the tab.
- **Row caps.** This skill creates no spec rows. If a variant ever must:
  `row_create_batch` caps at 50 top-level rows per call and 20 children per
  parent row, and its rows have **no status field**; a single `row_create`
  does accept `status`.
- **Working notes stay in context.** Nothing intermediate is written to
  Speqq or disk — only clean, final queue items land anywhere.

## What the tools cannot do yet

Prescribe only mechanisms that exist. Where a needed write is missing, this
skill uses the closest real one and labels it interim so the gap stays
visible:

- **Queue item → spec link.** `queue_add` cannot set `linked_document_id`.
  Interim: the `Spec: <spec_id>` description line, pending R2 field-write
  support.
- **Priority at creation.** `queue_add` has no priority parameter. Interim:
  `queue_update_item` immediately after, pending the R2 one-call create.
- **Scoped queue reads.** `queue_read` returns the entire queue. Interim:
  read once, filter in context, pending R2 scoped reads.
- **Spec-by-branch lookup.** None exists. Interim: the bounded
  `spec_list` + `spec_read` scan in Finding the spec, rung 3, pending the R2
  lookup.
- **Row timestamps and SHAs.** On spec rows, `cell_set` does write `branch`
  (with `branch_repository` when several repos are connected), but fields
  like `work_started_at` and `completed_commit_sha` have no `cell_set`
  parameter — they are system-managed. If a run must record such facts,
  put them in the row's description or a custom column via `custom_fields`,
  marked interim pending R2 field-write support. This skill only reads
  these fields (rung 3); it never needs to write them.

## Quality gate

Run against the proposal before the checkpoint, in conversation only:

- Every candidate maps to exactly one plan step, in plan order; no bundles,
  no invented work.
- Every title is commit form and would make sense to a teammate reading the
  queue cold.
- Every description carries the `Spec:` id line and the step reference; no
  URLs, no conversation references, no diary text.
- Every skip has a named reason the user can veto.
- Priorities map onto the workspace's actual visible labels.
- A re-run of this skill immediately afterward would create zero items.

Fix failures and re-check, up to 3 iterations; if something still fails,
tell the user exactly what before the checkpoint.

## Completion report

After filing, report:

- The spec (title and `spec_id`) and the workspace.
- Items created — title, item id, priority, status — and items skipped, each
  with its reason.
- Any interim mechanisms used (embedded spec id, two-call create, bounded
  branch scan) so the user knows what tightens when the R2 app work lands.
- Next step: spec-implement picks work up from these queue items; re-run
  spec-queue after the plan changes — dedup makes it idempotent.
