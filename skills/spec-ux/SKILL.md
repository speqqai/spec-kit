---
name: spec-ux
description: >-
  Write the design part of a feature specification — screens, data states,
  flows, and mockups — grounded in the actual repo's UI and design system, and
  add it as a Design tab on the feature spec in Speqq. Standalone but composes
  with spec-product, spec-eng, and spec-qa onto one spec; creates the feature
  spec first if none exists. Use when asked to design a feature, spec the UX,
  document screens and states, or add a design tab to a spec.
---

# spec-ux

You own the **Design** part of one feature spec. Work in three phases — ground, then
brainstorm, then write. Only the write phase touches Speqq; grounding and brainstorming
stay in your working context and never enter the spec. Design against the product
**Requirements** and reference each one by its **exact plain title** so the design maps
back to one source of truth.

## When to use this skill

- The user asks to design a feature or spec its UX.
- The user asks to document screens, data states, interactions, or flows for a feature.
- The user asks to add or update a Design tab on a feature spec.
- spec-product has produced Requirements and the feature now needs its design section.

## Operating rules

These hold for the entire run. No exceptions.

1. **Speqq only, zero local artifacts.** This skill never creates or modifies any file in
   the user's repo or on their machine. Every artifact lands in the Speqq spec over MCP.
   Grounding and brainstorm notes stay in conversation context only — they never enter
   the spec and never become files.
2. **The working tree is truth.** Read the real repository with your own file tools
   (read, grep, glob). Do not trust any external or indexed code graph. Never name a
   stack, library, or component that you did not read from this repo in this session.
3. **All writes to one spec are sequential.** Wait for each Speqq call to return before
   issuing the next. Parallel writes to the same spec collide and silently drop content.
4. **Nothing lands without approval.** Settle the design direction with the user before
   writing, and checkpoint each requirement's section with the user before it goes into
   the spec. Only clean, final, present-tense production prose lands in Speqq.

## Process

Follow the stages in order. Each stage has an exit condition — do not advance until it
is met.

### Stage 0 — Preflight

- **Check the Speqq MCP is connected.** If no `mcp__speqq__*` tools are available in
  this session, STOP before doing anything else. Tell the user the Speqq MCP is not
  connected and walk them through connecting it for their harness (add the Speqq MCP
  server to the agent's MCP configuration, then restart the session so the tools load).
  Never fail silently, and never fall back to local files.
- **Resolve the workspace.** Call `list_workspaces` before any other Speqq call. If
  there is one workspace, use it. If there are several, ask the user which one and wait
  for the answer.
- **Exit:** Speqq tools respond and you hold a confirmed `workspace_id`.

### Stage 1 — Ground

Read before you design. Everything you later specify must come from what you read here.

- **Workspace context (optional grounding).** Call `get_context` for the workspace. If
  product context, principles, or design conventions exist there, absorb them; if not,
  continue without them.
- **Design system.** Find the components, primitives, design tokens, spacing and
  typography scale, and layout patterns this repo already uses. Note the house rules
  from any agent-instruction file, contributing/style doc, or component-library README
  in the repo.
- **Existing UI.** Find the screens the feature attaches to and the patterns they follow
  today: how tables, rows, panels, forms, empty states, loading states, and errors look
  now. Record file paths alongside each pattern so every later claim is traceable.
- **Requirements.** Locate the feature spec (Stage 4 step 1 describes how). If it
  exists, `spec_read` its Requirements tab and copy the exact requirement titles —
  verbatim, not paraphrased. If no spec exists yet, design against the requirement
  titles the user gives you. Identify which requirements are user-facing; only those get
  design sections.
- **Exit:** You can name, with repo file paths, the components and treatments this
  feature will reuse, and you hold the exact plain title of every user-facing
  requirement.

### Stage 2 — Brainstorm and align

Work stays in your context. Nothing is written to Speqq in this stage.

**Clarify intent first.** Derive up to THREE clarifying questions. They must:

- Be generated from the user's phrasing plus signals from the requirements and the repo
  — no pre-baked catalog.
- Only ask about information that materially changes the design (e.g., which existing
  surface the feature lives on, density vs. clarity, primary audience or device).
- Be skipped individually when the answer is already unambiguous.
- Prefer precision over breadth. Never ask the user to restate what they already said.

When presenting options inside a question, use a compact table with columns
Option | Candidate | Why It Matters, five options maximum. If the user cannot answer,
default to the dominant pattern the repo already uses and say so explicitly.

**Then enumerate options per requirement.** For each user-facing requirement, lay out
the realistic screen and interaction options and the single tradeoff that separates them
(e.g., inline cell vs. drawer, optimistic vs. confirmed update, badge vs. full panel).
Settle on one approach per requirement — prefer the option that reuses existing patterns
— and present the settled direction to the user as a short per-requirement summary.

- **Exit:** The user has agreed to the design direction for every user-facing
  requirement.

### Stage 3 — Write, one requirement at a time

Draft the Design section requirement by requirement, presenting each section to the user
and getting a checkpoint before moving to the next. Only clean, final, present-tense
prose survives to Stage 4 — no options, no notes, no rationale trails.

Each section is headed by the requirement's **exact plain title** and covers:

- **Screen(s):** where it lives and which existing components/primitives render it.
- **Four data states:** loading, empty, error, success — each described with the repo's
  real treatments (skeletons, muted affordances, inline error/retry, populated view).
  Never fake missing data: an error state shows the error, not a stale success.
- **Key interactions:** the actions available on the screen and their results.
- **Responsive behavior:** how it holds up from wide to narrow using the repo's
  established truncation/reflow patterns.
- **Mockup:** link a screenshot or mockup URL only if one actually exists. Never invent
  a placeholder URL. When none exists, omit the line entirely.

Write non-trivial multi-step flows as a fenced ```mermaid block — the Design page
renders it. Write valid mermaid; the write tools validate the fence and reject the write
if it is broken.

#### Illustrative fragment (structure to mirror, not the stack)

> **A linked row shows its branch live status**
>
> **Screen:** the branch-status cell on a table row, built from the repo's existing
> table-cell and inline-badge primitives.
>
> **States**
> - *Loading* — the cell renders the repo's skeleton/placeholder treatment; the row
>   stays interactive.
> - *Empty* — no branch linked: the cell shows the repo's muted "Link branch"
>   affordance.
> - *Error* — the status read fails: the cell shows the repo's inline error/retry
>   treatment; last-known state is not faked.
> - *Success* — a badge shows branch name plus ahead/behind and checks, colored with the
>   repo's status tokens.
>
> **Interactions:** hover reveals the full branch ref via the repo's tooltip primitive;
> click opens the branch on the provider.
>
> **Responsive:** at narrow widths the badge collapses to icon + count using the repo's
> established cell-truncation pattern.

- **Exit:** Every user-facing requirement has an approved section covering all five
  points above, and every multi-step flow has a mermaid diagram.

### Stage 4 — Land in Speqq

Write over MCP only. Run these steps strictly in order, waiting for each call to return
before the next.

1. **Locate the feature spec.** There is no spec search over MCP — call `spec_list` for
   the workspace and filter the titles client-side for a match on the feature. If a
   matching spec exists, reuse it — never create a duplicate — and `spec_read` it to
   confirm its tabs and re-verify the exact Requirements titles.
2. **Create the spec only if none exists.** Call `spec_create` with the feature title in
   commit form: `feat: <feature>` or `feat(scope): <feature>` (`fix(scope): <feature>`
   for defect work). spec-product owns Overview and Requirements; when spec-ux runs
   first, the spec simply starts with the Design tab you are adding.
3. **Add or patch the Design tab.**
   - If no Design tab exists: `tab_create_page` on the spec, title `Design`, with the
     full approved Design markdown (per-requirement sections plus mermaid flows).
   - If a Design tab already exists: never create a duplicate. `spec_read` the tab
     first, then patch it. `spec_markdown_tab_update` is PATCH-based — it takes a
     `patches` array of `{old_str, new_str}` edits, and each `old_str` must occur
     exactly once in the tab's current markdown; there is no whole-document replace
     parameter. An empty `old_str` is allowed only to initialize a tab that is
     currently empty. To revise one requirement's section, anchor `old_str` on that
     section's verbatim text; to add a new section at the end, use
     `spec_markdown_tab_append`.
   - If a write returns a mermaid validation error, fix the mermaid source and retry the
     same markdown write.
4. **Set mockup links (optional).** Only for requirement rows that have a real
   mockup/screenshot URL, and only if a Requirements table tab exists. If that table has
   no `Mockup` column, add one with `column_create` (type `link`), then `cell_set` the
   URL on each relevant requirement row — passing it in `custom_fields` keyed by the
   `Mockup` column name — one call at a time, in sequence. Skip this step entirely
   when no real URL exists.

- **Exit:** The Design tab renders the approved sections, mermaid diagrams display, and
  any mockup cells hold real URLs. Report the spec and tab to the user.

## Quality gate — test the writing before it lands

Before each write, audit the section against these checks. Fix failures — do not list
them. The metaphor: if the design section is prose, these are its unit tests.

- Is the section headed by the requirement's exact plain title, copied verbatim from the
  Requirements tab? [Traceability]
- Does every named component, token, and pattern trace to a file you read in this repo
  during grounding? [Grounded]
- Are all four data states — loading, empty, error, success — described with the repo's
  real treatments, not generic ones? [Completeness]
- Does the error state avoid faking data or showing stale success? [Correctness]
- Is responsive behavior specified using the repo's established truncation/reflow
  patterns? [Completeness]
- Is every mockup link a real URL — or omitted? [No placeholders]
- Is the prose present-tense, plain, and free of filler, marketing, TODOs, options, and
  diary notes? [Voice]
- Is the section lean — design only, with no restated requirement text and no
  engineering plan? [Scope]
- Does every multi-step interaction have a valid fenced mermaid flow? [Flows]

**❌ WRONG** — invented, vague, or borrowed from outside the repo:

- "The screen uses a modern card layout with a sleek loading spinner."
- "We could use a drawer here, or maybe a modal — TBD."
- "Mockup: https://figma.com/file/placeholder"

**✅ CORRECT** — grounded, final, and traceable:

- "The cell renders the repo's existing skeleton treatment — the same one its list rows
  use — while the status loads."
- "Deleting opens the repo's standard confirm dialog primitive; on confirm, the row is
  removed and the repo's toast treatment announces the result."

## Composition

spec-ux is standalone but composes with spec-product (Overview + Requirements),
spec-eng (engineering plan), and spec-qa (test plan) onto the same feature spec. Each
skill adds its own tab; none overwrites another's. When running alongside them, the same
sequential-write rule applies across the whole spec: one write at a time.
