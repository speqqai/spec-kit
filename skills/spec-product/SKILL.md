---
name: spec-product
description: Write the product half of a feature specification — the Overview and the testable Requirements — and create the feature spec itself in Speqq. Use when a user wants to spec what a feature does and who it is for, start a new feature spec, or capture product requirements with acceptance criteria. This skill creates the spec; spec-ux, spec-eng, and spec-qa add their tabs to the same spec. Runs on any codebase; it names no stack of its own.
---

# spec-product

Owns two parts of one feature spec: **Overview** (a page tab) and **Requirements**
(a table tab). It is the skill that creates the feature spec in Speqq; spec-ux,
spec-eng, and spec-qa add their tabs to the same spec. If a feature spec already
exists (the user ran another discipline skill first), reuse it and add these two
tabs — never duplicate.

Everything this skill produces lands in a Speqq spec over MCP. It is
codebase-agnostic: name no stack, library, or component except what you read
from the target repo at runtime.

## Preflight

1. **Speqq MCP must be connected.** If the Speqq MCP tools (`list_workspaces`,
   `spec_list`, `spec_create`, `tab_create_page`, ...) are not available, STOP
   before writing anything. Tell the user this skill writes only to Speqq and
   walk them through connecting the Speqq MCP server for their harness. Never
   fail silently, and never fall back to local files.
2. **Resolve the workspace.** Call `list_workspaces` before any other Speqq
   call. One workspace: use it. Several: ask the user which. Keep the
   `workspace_id` for every subsequent call.
3. **Zero local artifacts.** Never create or modify any file in the user's repo
   or machine. Grounding notes, brainstorm options, question queues, and drafts
   live in conversation context only. Only clean, final, present-tense prose is
   written to Speqq.

## Flow: ground, then brainstorm, then write

Only the Write phase touches Speqq.

### Phase 1 — Ground

- Read the actual repository with your own file tools (read, grep, glob). Do
  not rely on any indexed or external code graph — the working tree is the
  source of truth.
- Read the repo's standards and conventions (agent instruction files,
  contributing or style docs, existing patterns) and derive the constraints and
  non-goals from THIS repo.
- Call `get_context` for the workspace ProductContext and treat it as optional
  grounding: `product_context.users` supplies the product's defined personas —
  this is where the Overview's user comes from. If no ProductContext exists,
  note the gap and continue.
- From the user's feature description, extract the key concepts: actors,
  actions, data, constraints.
- For unclear aspects, make informed guesses from repo context and common
  product patterns. Mark an item `[NEEDS CLARIFICATION: specific question]` in
  your working notes only when all three hold: the choice significantly impacts
  scope or user experience, multiple reasonable interpretations diverge, and no
  reasonable default exists. **Maximum 3 markers.** Prioritize by impact:
  scope > security/privacy > user experience > detail. Markers are resolved in
  Brainstorm and never land in Speqq.
- Derive a feature short name (2-4 words, action-noun form, preserve technical
  terms and acronyms) and from it the commit-form spec title:
  `feat: user auth`, `feat(table): branch links`, `fix(checkout): payment timeout`.

Exit: you can describe what the product does today in the area being specced,
who the personas are, and what is genuinely undecided.

### Phase 2 — Brainstorm

Settle one approach with the user before anything is written.

**Options.** Enumerate the realistic product options and the tradeoff that
separates them — the scope and behavior boundaries (one linked item per row vs
many; live status read vs stored snapshot; who may change what). Present them
concisely with a recommendation and reasoning, and let the user choose.

**Clarification loop — up to 5 targeted questions.** Resolve your
`[NEEDS CLARIFICATION]` markers plus coverage gaps. First scan the draft scope
against this taxonomy, marking each category Clear / Partial / Missing:

- Functional scope and behavior: core user goals, explicit out-of-scope
  declarations, role and persona differentiation
- Domain and data: entities and relationships, identity and uniqueness rules,
  lifecycle states, volume assumptions
- Interaction and flow: critical user journeys; error, empty, and loading states
- Non-functional: performance, reliability, security and privacy, compliance
- Integration and dependencies: external services and their failure modes
- Edge cases and failure handling: negative scenarios, limits, conflicts such
  as concurrent edits
- Constraints and tradeoffs: explicit constraints, rejected alternatives
- Terminology: one canonical term per concept
- Completion signals: are the acceptance criteria testable
- Placeholders: unresolved markers, ambiguous adjectives lacking quantification

Queue candidate questions only for Partial or Missing categories where the
answer materially changes scope, requirements, or acceptance criteria. Rank by
impact times uncertainty; cap the queue at 5. Then run the loop:

- Ask EXACTLY ONE question at a time; never reveal the rest of the queue.
- Every question must be answerable with either a short multiple-choice
  selection (2-5 mutually exclusive options) or a short phrase (5 words or
  fewer).
- Lead with `**Question:**` followed by a full interrogative ending in `?` that
  makes sense on its own — never a topic label or requirement id as the
  question. Follow it with one plain-language sentence on why it matters.
- Multiple choice: state `**Recommended:** Option X - <reasoning>` first, then
  a table of `| Option | Description |` rows. Tell the user they can reply with
  a letter, accept with "yes"/"recommended", or give their own short answer.
- Short answer: state `**Suggested:** <answer> - <reasoning>` and invite the
  user to accept or supply their own (5 words or fewer).
- If an answer is ambiguous, disambiguate within the same question — it does
  not consume the quota.
- Stop when critical ambiguities are resolved, the user signals done, or 5
  questions have been asked. If high-impact items remain at the cap, flag them
  as deferred with rationale.
- If nothing needs asking, say "No critical ambiguities detected" and move on.

**Integration.** Fold each accepted answer into your working draft immediately —
it becomes Overview or Requirements content. No separate clarification log
lands in the spec. If an answer invalidates an earlier assumption, replace the
assumption; keep no contradictory text.

Exit: one settled approach, all markers resolved or explicitly deferred by the
user, scope boundaries stated.

### Phase 3 — Write

Write section by section with a user checkpoint after each: draft the section
in conversation, run the quality gate below, show it to the user, and only
after their go-ahead write it to Speqq. Overview first, then Requirements.

## Overview

Name the feature, say what it does and who it is for. Present tense. No
history, no marketing, no rationale, no implementation. Identify the user from
the product's defined personas (read via `get_context`); never invent one. If
no persona fits, leave the user slot open and record it as an open item with
the user.

Worked Overview (branch links, illustrative):

> Branch links connects a table row to a GitHub branch and shows that branch's
> live status on the row. It is for the developer who tracks implementation
> work against rows in a table.

If a flow genuinely clarifies the Overview, include it as a fenced
```` ```mermaid ```` block in the page markdown — the product renders and
validates Mermaid natively. If a write returns a Mermaid-specific error, fix
the Mermaid source and retry the write.

## Requirements

Each requirement is one clear, testable, plain-language statement.

- **Title** is the capability as a sentence — "User can link a table row to a
  GitHub branch".
- **Description** is the constraints, limits, and who it applies to.

**Requirement vs. acceptance criterion.** A requirement is a distinct
observable behavior — a parent row. A criterion is a condition of that
behavior — a Given/When/Then child row. "The linked branch persists on reload"
is a criterion of the link requirement, not a requirement of its own.

**No user stories.** This skill diverges from user-story templates on purpose:
each requirement is one testable capability statement, not a journey or a
persona narrative.

**Acceptance criteria** are Given/When/Then child rows covering the happy path
plus the edges the requirement implies — invalid input, permission denied,
empty, and error. Each criterion's expected outcome matches what this product
actually does: grounding tells you whether a missing precondition errors,
prompts, or falls back — write the behavior this product chose, not a rule
imported from elsewhere.

**Fields.** `priority` from the agreed ranking; `review_status` draft; `status`
stays at its default until the behavior ships, then done (set via `cell_set`). An OPTIONAL **Mockup** link
column carries a screenshot or mockup URL on user-facing rows — set it only
when a real URL exists; never invent one.

### Avoid these

| Anti-pattern | Example | Fix |
|---|---|---|
| User story | "As a dev I want to link a branch so I can track work" | State the capability: "User can link a table row to a GitHub branch" |
| Task | "Add a branch column to the table" | Describe observable behavior, not the work |
| Compound | "User can link a branch and see its status" | Split into two requirements |
| Vague | "Branch linking works well" | Name the specific testable behavior |
| Implementation leak | "Store the branch in the row's branch column" | Describe behavior, not mechanism |
| Criterion as requirement | "Linked branch persists on reload" | Fold into the link requirement's criteria |

### Worked requirements (branch links, illustrative)

**User can link a table row to a GitHub branch** — A row editor picks a branch
from a connected repository; the row stores one branch. Applies to any row in
a table.
- Happy: Given a connected repo, When the user picks a branch for a row, Then the row shows the linked branch and it persists on reload.
- Invalid: Given the branch picker, When the user names a branch that does not exist on the repo, Then the row rejects it and shows an error.
- Permission-denied: Given a viewer, When they open the row, Then the branch control is read-only.
- Empty: Given a repo with no branches, When the user opens the picker, Then it shows an empty state.
- Error: Given the branch service is unreachable, When the user opens the picker, Then the row surfaces an error and lists no branches.

**A linked row shows its branch live status** — A linked row displays the
branch's current status read live from the source, not a stored copy.
- Happy: Given a row linked to an active branch, When the row loads, Then it shows the branch's current status.
- Empty: Given a row with no linked branch, When it loads, Then it shows no status indicator.
- Invalid: Given a linked branch that no longer exists, When the row loads, Then it shows a branch-not-found state.
- Error: Given the status read fails, When the row loads, Then it shows an error state.

**Only editors and admins can change a row branch** — Changing a row's linked
branch is limited to editors and admins. Viewers see the link and status but
cannot change them.
- Happy: Given an editor, When they change the branch, Then the new branch is saved.
- Happy: Given an admin, When they change the branch, Then the new branch is saved.
- Permission-denied: Given a viewer, When they attempt to change the branch, Then the action is blocked and the branch is unchanged.

## Writing to Speqq

Write over MCP only; never write local files. Hard rules for every write:

- **Sequential writes.** All tab, column, and row writes to one spec are
  sequential — wait for each call to return before issuing the next. Parallel
  writes to one spec collide and silently drop.
- **Patch semantics.** `spec_markdown_tab_update` is patch-based: it takes a
  `patches` array of `{old_str, new_str}` edits, and each `old_str` must occur
  exactly once in the tab. An empty `old_str` is allowed only to initialize an
  empty tab. Never assume full-document replace.
- **No spec search over MCP.** Use `spec_list` and filter titles client-side.
- **Fixed enums.** Spec status: draft/in_review/rejected/approved/queued/
  building/released. Row status: new/backlog/todo/in_progress/done/cancelled.
  Review status: draft/in_review/approved. Row priority: high/medium/low —
  map P1→high, P2→medium, P3→low. Map any workflow state onto these; put
  unmappable labels in description text or a custom column.

The write sequence:

1. **Locate or create the spec.** `spec_list` for the workspace and filter
   titles client-side for the feature. If a matching spec exists (another
   discipline skill ran first), `spec_read` it and reuse it — never duplicate.
   Otherwise `spec_create` with `workspace_id` and the commit-form `title`
   (`feat: X`, `feat(scope): X`, `fix(scope): X`). Keep the `spec_id`.
2. **Overview.** `tab_create_page` with `title: "Overview"` and
   `content_markdown` set to the final approved prose. If an Overview tab
   already exists, patch it with `spec_markdown_tab_update` instead of adding
   a duplicate.
3. **Requirements table.** `tab_create_table` with `title: "Requirements"`.
   Keep the `tab_id`. If a Requirements tab already exists, add rows to it
   rather than creating a second.
4. **Mockup column.** `column_create` with `name: "Mockup"`,
   `column_type: "link"` — skip if the column already exists.
5. **Rows.** `row_create_batch` — one entry per requirement with `title`,
   `description`, `priority` (high/medium/low), `review_status: "draft"`, an
   optional `custom_fields: {"Mockup": "<url>"}` only when a real URL exists,
   and nested `acceptance_criteria` (each a Given/When/Then child with `title`
   and `description`). Limits: max 50 top-level rows per call and max 20
   `acceptance_criteria` children per row — chunk larger sets across
   sequential calls. `row_create_batch` has **no status field**; batch rows
   get the default status. Keep the row ids.
6. **Shipped behavior.** For each requirement whose behavior already ships
   today, `cell_set` its row `status` to `"done"`. Leave everything else at
   the default.

## Quality gate

Run this against the drafted section before each checkpoint. It lives in
conversation only — never write a checklist anywhere.

Content quality:
- No implementation details (languages, frameworks, APIs, component names).
- Focused on user value; readable by a non-technical stakeholder.
- Present tense; no filler, marketing, rationale, TODO, or diary text.

Requirement completeness:
- No `[NEEDS CLARIFICATION]` markers remain.
- Every requirement is one distinct, testable, unambiguous behavior — none
  match a row of the anti-pattern table.
- Every requirement covers the happy path plus its invalid, permission-denied,
  empty, and error edges; each outcome is the behavior this product actually
  chose.
- Scope is bounded; assumptions the user accepted are reflected in
  descriptions.

Readiness:
- Overview user is drawn from a real persona, or the open item is recorded.
- Requirement titles are stable so spec-ux, spec-eng, and spec-qa can map
  their tabs back to this source of truth.
- Priorities are set and mapped to high/medium/low.

Fix failures and re-check, up to 3 iterations. If items still fail, tell the
user exactly what is unresolved before writing. If markers remain, return to
the Brainstorm question loop (within its 5-question quota) or ask the user
directly.

## Completion report

After the final write, report:

- Spec title and `spec_id`, and the workspace it lives in.
- Tabs written or updated, requirement count, and acceptance-criteria count.
- Open items and any deferred questions.
- Next step: spec-ux, spec-eng, and spec-qa add their tabs to this same spec.
