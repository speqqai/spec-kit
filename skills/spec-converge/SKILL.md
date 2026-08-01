---
name: spec-converge
description: >-
  Reconciles the actual codebase against a feature spec in Speqq: reads the
  spec's Requirements and Implementation plan over MCP, honestly assesses what
  the code delivers today, flips genuinely-done rows to done, and appends the
  remaining gap as new concrete plan steps — never rewriting finished prose,
  never duplicating steps that already cover the gap. Use when a user asks to
  converge, reconcile code against a spec, check drift, mark what is done, or
  find what is left to build. Append-only and codebase-agnostic; it assesses
  the present state of the working tree, not git history, and modifies no
  application code.
---

# spec-converge

Closes the gap between what a feature spec calls for and what the codebase
implements. It reads the spec's **Requirements** table and **Implementation
plan** tab as the sole source of intent, inspects the present code, marks
genuinely-done work done, and appends the remaining gap as new plan steps so
spec-implement can complete them. Its only writes land in the spec over Speqq
MCP — status flips and appended steps. It modifies no application code, and it
is not a diff tool: it assesses the present state of the working tree, with no
git history or branch comparison.

**Append-only, never rewrite.** Never rewrite, renumber, reorder, or delete
finished prose, existing plan steps, or existing rows — including steps a prior
convergence pass appended. When the code already satisfies everything, write
nothing at all and report converged.

## Preflight — before any other step

1. **Confirm Speqq MCP is connected.** You need `list_workspaces`, `spec_list`,
   `spec_read`, `cell_set`, `row_create`, `spec_markdown_tab_append`, and
   `queue_read`. If the Speqq tools are not available, STOP before doing
   anything: tell the user, walk them through connecting the Speqq MCP server
   for their harness, and resume only once it is connected. Never fail
   silently. Never fall back to local files.
2. **Resolve the workspace.** Call `list_workspaces` before any other Speqq
   call. One workspace: use it. Several: ask the user which. Every subsequent
   workspace-scoped call (`spec_list`, `queue_read`, `get_context`) takes that
   `workspace_id`; spec-scoped calls key off the resolved `spec_id` instead.
3. **Zero local state.** This skill never creates or modifies any file on the
   user's machine — no pointer files, no notes files, no findings markdown.
   Assessment notes live in agent context only. Reading the working tree and
   running read-only git commands (`git branch --show-current`) is fine;
   converge itself performs no git writes and changes no code.

## Resolve the active spec

Resolve in exactly this order and stop at the first rung that answers. Never
read or write a local pointer file — the active spec is always derived from
Speqq-side data plus the checkout itself.

1. **A queue item the user picked.** `queue_read` the workspace queue and use
   that item's `linked_document_id` as the spec. (Today `queue_read` returns
   the full queue; scoped queue reads are queued R2 app work.)
2. **The spec the user names.** There is no spec search over MCP: `spec_list`
   the workspace and filter titles client-side. Feature spec titles are
   commit-form (`feat: X`, `feat(scope): X`, `fix(scope): X`) — match against
   those.
3. **The current git branch matched against row branch values.** No by-branch
   lookup exists over MCP yet (it is queued R2 app work), so this rung is a
   bounded interim scan — label it as such when you report: read
   `git branch --show-current`; `spec_list`; take candidates with status
   `building` plus the most recently updated specs (cap the scan at roughly
   ten); `spec_read` each candidate and compare its rows' `branch` values to
   the current branch; first exact match wins.
4. **Specs with status `building`.** Exactly one: confirm it with the user.
   Several: ask which.
5. **Otherwise ask.** Present a short workspace overview from `spec_list`
   (title, status, updated) and let the user choose.

## Flow: Ground → Brainstorm → Write

Only Stage 3 writes to Speqq, and only after the Stage 2 checkpoint.

### Stage 1 — Ground

1. **Read the spec.** `spec_read` the resolved spec for its tab list, then the
   tabs that carry intent: the Requirements table (every row, its child
   Given/When/Then criteria, and current statuses) and the Implementation plan
   tab in full — page markdown, or plan-step rows where the spec keeps its
   steps in a table tab. Include any prior Convergence section or previously
   appended steps: they are existing intent and feed the dedup gate.
2. **Stop on missing prerequisites.** No Requirements tab: STOP and direct the
   user to spec-product. No Implementation plan tab: STOP and direct the user
   to spec-eng. Never invent intent, and never produce a partial assessment.
3. **Optional grounding.** Call `get_context` for workspace and product
   context; if it is empty or missing, proceed from the spec and repo alone.
4. **Read the code.** Use your own file tools (read, grep, glob) on the actual
   working tree — not an indexed or external code graph. Bound the assessment
   to a code-scope map: the files and surfaces the Implementation plan names,
   plus a keyword search for the concepts each requirement describes. Do not
   infer scope beyond what the spec and plan define.

**Exit:** an intent inventory — one stable key per requirement, acceptance
criterion, and plan step — and a code-scope map naming the real files in scope.

### Stage 2 — Brainstorm (assess, then agree the delta)

**Verdicts require evidence.** For each item in the intent inventory, inspect
the code in scope and record exactly one verdict, each citing the file or
surface observed:

- **done** — the behavior is present and observably satisfies the item. A
  requirement is done only when its acceptance criteria hold; a plan step is
  done only when its Done-when condition holds in the code as it stands.
- **partially met** — work exists but does not fully satisfy the item. Name
  what exists, where, and precisely what is missing.
- **unmet** — the work is absent from the code entirely.

Never mark aspirationally: no verdict of done because a step "should" be
finished, was claimed finished, or exists on a branch you have not read. If
you did not see it in the code, it is not done.

**Classify each gap** (anything not fully done) by type: `missing` (absent),
`partial` (incomplete), `contradicts` (the code conflicts with stated intent
or a repo standard — read the repo's own instruction and convention documents
during grounding and treat them as governing constraints), or `unrequested`
(code not called for by the spec — surfaced for awareness; converge never
deletes code, it appends a step to review, justify, or remove it).

**Assign severity:** CRITICAL (violates a governing repo standard, or a
missing/contradicts gap blocking a high-priority requirement's baseline
behavior), HIGH (missing or partial on a core requirement or criterion),
MEDIUM (partial on a secondary requirement, or an unjustified unrequested
addition), LOW (polish and low-risk leftovers).

**Dedup gate.** Before drafting any new step, re-read the existing plan steps
and rows gathered in Stage 1 — including prior Convergence sections. A gap
already covered by an existing step, done or pending, gets no new step; the
existing step is the work item. Only genuinely uncovered work becomes a new
step.

**Report the delta before writing.** Present a compact findings summary — a
table of finding, gap type, severity, source requirement or step, and the
evidence observed — plus counts: items checked, verdicts by kind, findings by
gap type and severity, rows to flip, and steps to append (or none). This is
the checkpoint: get the user's go-ahead before any write.

**Converged branch.** Zero findings means zero writes — no empty Convergence
header, no status churn. Report converged with the counts of what was checked
and recommend proceeding to review.

**Exit:** the user has agreed to the delta, or the run reported converged and
Stage 3 is skipped entirely.

### Stage 3 — Write

All writes to the spec are strictly sequential — issue one call, wait for it
to return, then issue the next. Parallel writes to one spec collide and
silently drop content.

1. **Flip genuinely-done rows.** For each requirement or plan-step row whose
   verdict is done, `cell_set` its `status` to `"done"`. Touch nothing else on
   the row — no description rewrites, no title edits. Rows already `done` stay
   untouched. Leave partially-met rows at their current status; their gap
   becomes an appended step.
2. **Append the gap as new steps**, ordered CRITICAL and HIGH first,
   contradictions before the rest. Each step is concrete in the spec-eng step
   form — Changes, Surfaces (real paths from grounding), Depends on, Done when
   (observable behavior) — and names the requirement title it delivers plus
   its gap type.
   - **Plan steps kept as table rows:** one `row_create` per step with
     `row_type` `"parent"`, `title`, `description`, and `status` (`"todo"`).
     For a large gap, `row_create_batch` caps at 50 top-level rows and 20
     children per call — chunk sequentially; every batch row requires both
     `title` and `description` — and has **no status field**: batch rows land
     at the default status, so follow with sequential `cell_set` calls only
     where a non-default status matters.
   - **Plan kept as a page tab:** one `spec_markdown_tab_append` adding a
     `## Convergence — <date>` section holding the new steps. Append is the
     only page write converge makes: it adds to the end and never touches
     finished prose. If a prior Convergence section exists, append a new,
     separately numbered one below it — never touch the old one, and never
     reuse its step numbers.
3. **Leave spec status alone.** Spec status is derived by the app: the
   server rejects any status value sent to `spec_update` ("Spec status is
   derived by the app and cannot be set directly"). Read it as a signal;
   never try to write it. Row status flips are how converge records
   progress.

## Writing to Speqq — hard rules

- **Sequential writes.** All writes to one spec are sequential; never parallel.
- **Patch semantics.** `spec_markdown_tab_update` is PATCH-based: a `patches`
  array of `{old_str, new_str}` where each `old_str` must occur exactly once
  in the tab; there is no whole-document replace parameter, and an empty
  `old_str` only initializes an empty tab. Converge's append-only contract
  means it does not use it on finished prose — additions go through
  `spec_markdown_tab_append`, which adds to the end of the tab.
- **No spec search over MCP.** Discovery is `spec_list` plus client-side
  title and status filtering, nothing else.
- **Fixed enums.** Spec status: `draft`/`in_review`/`rejected`/`approved`/
  `queued`/`building`/`released` — app-derived and rejected by `spec_update`, which converge
  reads but does not set. Row status: `new`/`backlog`/`todo`/`in_progress`/
  `done`/`cancelled` (set via `cell_set`).
  Never invent a status value; an unmappable label belongs in description
  text.
- **Field writability.** `cell_set` writes exactly: `title`, `description`,
  `status`, `priority`, `review_status`, `area`, `delivery_status`, `branch`
  (a GitHub branch link by name; trunk/default branches rejected) with
  `branch_repository` when several repos are connected, `linked_document_id`,
  and `custom_fields`. Rows also carry `work_started_at`, `work_completed_at`,
  `completed_commit_sha`, and `completed_commit_url`, but those fields have
  **no MCP write path** — never claim to have stamped them. To record a
  landing commit or timestamp as evidence, put it in the appended step text
  or a custom column via `custom_fields`, and label it interim pending the
  R2 field-write support.
- **Mermaid.** Any diagram in appended markdown is a fenced ```mermaid block;
  if a write returns a mermaid-specific error, fix the mermaid source and
  retry the same append.

## Quality gate

Run in conversation before declaring done — never write a checklist anywhere:

- Every verdict cites evidence from a file actually read; nothing is marked
  done aspirationally.
- No appended step duplicates an existing step, including prior Convergence
  steps; every appended step traces to a requirement title and gap type.
- Every appended step has real surfaces and an observable Done-when.
- Nothing existing was rewritten, renumbered, reordered, or deleted; a
  converged run wrote nothing.
- The delta was reported and agreed before the first write; all writes were
  sequential.
- No file was created or modified on the user's machine.

## Completion report

After the final write (or the converged verdict), report:

- Outcome: **converged** or **gap appended**, with the spec title and
  `spec_id`.
- Counts: requirements, criteria, and steps checked; verdicts by kind;
  findings by gap type and severity.
- Writes: rows flipped to done, steps appended and where (rows or the
  Convergence section), plus any interim mechanisms used (branch-scan
  resolution, evidence recorded in text pending R2 field-write support).
- Next step: run spec-implement to complete the appended steps; a follow-up
  converge pass should find fewer or no remaining items.
