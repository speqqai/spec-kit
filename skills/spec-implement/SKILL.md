---
name: spec-implement
description: >-
  Executes a feature spec's Implementation plan against the real codebase over
  Speqq MCP — resolves the active spec with zero local state, creates the
  feature branch, marks the queue item in progress, and works the plan
  milestone by milestone while flipping each spec row's status live (in_progress → done,
  commit recorded) so the spec is the single progress ledger. Use when a user
  wants to build, implement, or execute a spec, start work on a queued feature,
  or resume implementation on an existing feature branch. Requires an
  Implementation plan tab written by spec-eng; stops and directs the user there
  if none exists. Fully codebase-agnostic — every command, convention, and
  validation gate comes from what the agent reads in THIS repo, never from
  assumption.
---

# spec-implement

Executes the Implementation plan that spec-eng wrote, against the real working
tree. The spec's table rows are the live progress ledger: row status flips
replace checklist files and `[X]` markers — there is no tasks file, no
progress markdown, no local pointer. Git branches and commits ARE the
implementation work, and they are the only things this skill ever writes to
the user's machine.

## Preflight — before any other step

1. **Speqq MCP must be connected.** You need `list_workspaces`, `spec_list`,
   `spec_read`, `cell_set`, `row_create`, `queue_read`,
   `queue_update_item`, `spec_markdown_tab_update`,
   `spec_markdown_tab_append`, and `get_context`. If the Speqq tools are not
   available, STOP before doing anything: tell the user this skill reads its
   plan from and reports its progress to Speqq only, walk them through
   connecting the Speqq MCP server for their harness, and resume once
   connected. Never fail silently. Never fall back to a local task list.
2. **Resolve the workspace.** Call `list_workspaces` before any other Speqq
   call. One workspace: use it. Several: ask the user which. Keep the
   `workspace_id` for every subsequent call.
3. **Zero local state.** Never create a pointer file, notes file, progress
   file, or scratch markdown anywhere on the user's machine. Working notes —
   the step→row map, gate results, drift observations — live in conversation
   context only. The single exception is git work that IS the implementation:
   branching, editing source, committing. That is the deliverable, not state.

## Resolving the active spec

Resolve which spec to build from Speqq-side data alone, in exactly this
order. Stop at the first rung that resolves. Never read or write a local
pointer file.

a. **A queue item the user picked.** `queue_read` the workspace queue and use
   that item's `linked_document_id`. If the item links no spec, fall through
   and ask (rung e) — never guess.
b. **The spec the user names.** `spec_list` and filter titles client-side —
   there is no spec search over MCP. Ambiguous match: show the candidates and
   ask.
c. **The current git branch matched against row branch values.** No by-branch
   lookup exists over MCP yet, so the interim is a bounded scan: `spec_list`,
   keep specs with status `building` plus the few most recently updated
   candidates (cap the scan at roughly ten), `spec_read` each and compare its
   rows' `branch` values to `git branch --show-current`. Exact match wins.
   Label this rung interim pending the R2 by-branch lookup.
d. **Specs with status `building`.** One: propose it and confirm. Several:
   list them and ask.
e. **Otherwise** present a short workspace overview — spec titles and
   statuses from `spec_list` — and ask the user to choose.

## Stage 1 — Ground

Read everything before changing anything.

1. **The spec.** `spec_read` the resolved spec's tab list. **STOP if there is
   no Implementation plan tab**: tell the user this skill executes plans and
   does not invent them, and direct them to spec-eng to write one. Do not
   proceed on a System design tab alone, and do not improvise steps.
2. **Plan and design.** Read the Implementation plan tab in full — current
   build state, milestones, steps with Changes / Surfaces / Depends on / Done
   when. Read the System design tab if present for architecture, contracts,
   and failure conventions.
3. **The rows.** Read the spec's table tabs — Requirements, and any task
   table the spec carries — with each row's id, title, status, and branch
   value. Build the step→row map in working notes: each plan step maps to the
   row whose exact title its milestone names. Steps that deliver no row (pure
   scaffolding) report progress in conversation only.
4. **Workspace context.** `get_context` for optional product grounding. Empty
   or missing: proceed from the repo alone.
5. **The repo.** Read the working tree with your own file tools. Read the
   repo's instruction and convention documents wherever they live. Discover
   the validation gates from the repo itself — its manifest scripts, CI
   configuration, makefiles, contributor docs. The gates you will run are the
   repo's own commands, never assumed and never invented.
6. **The worktree.** Run `git status`. If the tree is dirty, surface the
   exact state to the user and ask how to proceed before touching anything.
   Never stash, discard, or commit pre-existing changes without explicit
   instruction.

**Exit:** plan read in full, every step mapped to its row or marked
row-less, validation gates named from repo files, worktree state settled
with the user.

## Stage 2 — Execution review

Settle the run with the user before the first write.

- **Verify the plan is executable.** Check each step's Surfaces against the
  tree as it exists now and the dependency order for forward references. If
  reality has drifted — surfaces gone, work already done, steps stale — stop
  and present the mismatch. Small drift: propose a plan-tab patch and apply
  it only with the user's approval. Large drift: direct the user to
  spec-converge (or spec-eng) to reconcile before executing.
- **Settle the branch.** Derive the branch name from the commit-form spec
  title: `feat: user auth` → `feat/user-auth`,
  `fix(checkout): payment timeout` → `fix/checkout-payment-timeout`. Never a
  trunk name (main, master, dev, develop, release/*) — the row branch link
  rejects them. If the matching branch already exists (a resumed run), reuse
  it instead of creating a second.
- **Present the run.** Milestone order, the steps in each, the gates that
  will run, and the rows that will flip. Get the user's go-ahead. Do not
  write to Speqq or create the branch before it.

## Stage 3 — Execute

### Start-of-run writes

Sequential, in this order, each confirmed before the next:

1. **Branch.** `git checkout -b <branch>` from the agreed base (or check out
   the existing branch on a resumed run).
2. **Row branch links.** For each row this run delivers, `cell_set` its
   `branch` to the branch name — pass `branch_repository` when several
   repositories are connected. This is what lets any later session resolve
   the spec from the branch alone. If the write is rejected because no
   GitHub repository is connected to the workspace, record the branch name
   instead as a final line appended to the row's existing description — read
   the current text first and carry it, since `description` replaces
   wholesale — and label it interim.
3. **Queue item.** If the run started from a queue item, `queue_update_item`
   its status to `in_progress`. Spec status is derived by the app —
   `spec_update` rejects status writes — so the queue item's status and the
   row flips are the live work signals.

`work_started_at` has no MCP write (see field writability below) — do not
attempt to stamp it; state plainly in the run report that it is unset pending
the R2 field-write support.

### The step loop

Work milestone by milestone, completing each before the next. Within a
milestone, honor every Depends on; steps with no shared surfaces and no
dependency may proceed together, but their row writes are still sequential.
Steps touching the same files run strictly in order. For every step:

1. **Flip in_progress first.** Before writing any code for a step,
   `cell_set` its row's status to `in_progress` (skip if a prior step of the
   same row already did). The ledger leads the work, not the other way
   around.
2. **Do the work.** The narrowest change that satisfies the step's Changes on
   its named Surfaces, in the repo's own patterns and conventions. Follow the
   repo's test-first convention where it has one.
3. **Validate.** Run the gates the repo defines — the step-relevant ones
   after the change, the full set at milestone end. A red gate blocks the
   step: fix and re-run until green. Never advance past a failure, and never
   flip a row `done` over a red gate.
4. **Commit.** Commit-form message scoped like the spec title. Capture the
   SHA.
5. **Flip done and record the commit — before moving on.** When the last
   step delivering a row lands, `cell_set` the row's status to `done` and
   record the SHA (mechanism below). Only then start the next step.
6. **Report.** One short progress note per step in conversation: step id,
   what changed, gate result, commit SHA, rows flipped.

**On failure or interruption:** halt a sequential run at the failing step —
report the error with context, suggest next steps, and leave the ledger
honest: started-but-unfinished rows stay `in_progress`, nothing is flipped
`done` speculatively. For steps running in parallel, finish and record the
successes, then halt and report the failures. If the user approves extra work
mid-run (a discovered gap), add it as a row with a single `row_create` —
which accepts `status` — rather than silently widening a step;
`row_create_batch` caps at 50 top-level rows and 20 children per call and
cannot set status, so batch-added rows land at the default.

### Row field writability

Prescribe only writes that exist. Via `cell_set` a row accepts: `status`,
`title`, `description`, `priority`, `review_status`, `delivery_status`,
`area`, `linked_document_id`, `branch` (+ `branch_repository`), and
`custom_fields` keyed by visible column name.

`work_started_at`, `work_completed_at`, `completed_commit_sha`, and
`completed_commit_url` exist on rows but have **no MCP write today** — the
app populates them from its repository integration. Never attempt to set
them and never fabricate their values. **Interim for the commit SHA**: read
the row's current description, then `cell_set` `description` to the existing
text plus a final line `Completed in commit <sha>` — `description` replaces
wholesale, so always carry the prior text. A spec may instead carry a visible
commit column; if one exists, write the SHA there via `custom_fields`. Both
are interim pending the R2 field-write support — say so in the run report so
the gap stays visible.

## Writing to Speqq

Hard rules for every write in this skill:

- **Sequential writes.** All spec, tab, and row writes to one spec are
  strictly sequential — issue one call, wait for it to return, then the
  next. Parallel writes to one spec collide and silently drop.
- **Patch semantics.** `spec_markdown_tab_update` takes a `patches` array of
  `{old_str, new_str}` edits; each `old_str` must occur exactly once in the
  tab. There is no whole-content parameter — even a full rewrite is expressed
  as patches. An empty `old_str` only initializes an empty tab. Pure additions at the end use
  `spec_markdown_tab_append`. This skill patches the plan tab only for a
  user-approved plan amendment — never to track progress; rows are the
  progress ledger.
- **No spec search over MCP.** Discovery is `spec_list` plus client-side
  title and status filtering.
- **Fixed enums.** Spec status (`draft`/`in_review`/`rejected`/`approved`/
  `queued`/`building`/`released`) is derived by the app — `spec_update`
  rejects any status value. Read it as a resolution signal; never try to set
  it. Row
  status: `new`/`backlog`/`todo`/`in_progress`/`done`/`cancelled`, set via
  `cell_set`. Never invent a value; an unmappable label belongs in
  description text.
- **Commit-form titles.** Spec titles are `feat: X`, `feat(scope): X`, or
  `fix(scope): X`; the branch name derives from them.
- **Working notes stay in context.** Grounding, the step→row map, and drift
  notes never land in the spec and never touch the user's disk.

## Completion checkpoint

When the plan's steps are exhausted (or the user stops the run):

1. **Validate.** Run the repo's full gate set one final time. Confirm each
   executed step's Done when actually holds, and that the row statuses match
   reality — no row `done` whose behavior is not observable.
2. **Report.** Milestones and steps completed, commits with SHAs, rows
   flipped, gates run and their results, and every remaining row that is not
   `done` — with why.
3. **Checkpoint with the user — do not decide alone.** Spec status is not this
   skill's to set, so disposition happens on the rows and the queue item:
   ask how to disposition remaining rows (leave, `todo`,
   `cancelled`) and apply via `cell_set`. If the run started from a queue
   item, propose `queue_update_item` to `done` and apply only on a yes. If
   the user wants a delivery stage recorded, set `delivery_status`
   (`code_complete`/`preview_ready`/`prod_launched`) via `cell_set`.
4. **State the interim gaps** left by missing writes: unset
   `work_started_at`/`completed_commit_sha` fields and any
   description-recorded SHAs or branch names, pending the R2 field-write
   support.

## Quality checklist

Verify before declaring done:

- The active spec was resolved by the ladder, in order, with zero local
  state; no pointer or notes file exists anywhere.
- The run stopped at preflight if the plan tab was missing, and on a dirty
  worktree until the user answered.
- The branch derives from the commit-form spec title, is not a trunk name,
  and is linked on every delivered row (or recorded interim with a label).
- The queue item went `in_progress` at start (spec status was never set by
  this run); every row flip used a real enum value; every `done`
  flip happened before work moved on and carries its commit record.
- Every gate run was a command discovered in this repo; no step advanced
  past a red gate.
- All Speqq writes were sequential; the plan tab was patched only for
  user-approved amendments.
- The completion checkpoint asked the user before any final status write,
  and the interim gaps were stated, not hidden.
