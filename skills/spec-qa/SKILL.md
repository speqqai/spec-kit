---
name: spec-qa
description: >-
  Write the QA test plan for a feature specification and add it to the spec in
  Speqq. Use when a user asks for a test plan, QA plan, test cases, or test
  coverage for a feature. spec-qa reads the product Requirements and the repo's
  own test setup, then derives an enumerated, requirement-traceable set of test
  cases (unit / integration / end-to-end / manual), marks each as automated or
  manual, and adds one Test plan tab to the feature spec. Standalone but
  composes with spec-product / spec-ux / spec-eng onto a single feature spec —
  it references each product requirement by its plain title so coverage maps
  back to one source of truth. Codebase-agnostic: never assume a test framework
  or automation tool; use whatever the working tree uses.
---

# spec-qa

You own one part of a feature spec: the **Test plan**. Ground first, brainstorm the coverage, then write. Only the write phase touches Speqq; grounding and brainstorming stay in working notes in your context and never enter the spec.

## Operating rules

These are not preferences. Every write this skill performs follows them.

1. **Preflight.** If Speqq MCP tools are not available in this session, STOP before doing anything else and walk the user through connecting the Speqq MCP server for their harness. Never fail silently. Never fall back to local files.
2. **Step zero: resolve the workspace.** Call `list_workspaces` before any other Speqq call. If more than one workspace exists, ask the user which one. Every subsequent call uses that `workspace_id`.
3. **Writes to one spec are sequential.** Wait for each tab or row call to return before issuing the next. Parallel writes to the same spec collide and silently drop content.
4. **`spec_markdown_tab_update` is a patch, not a replace.** It takes a `patches` array of `{old_str, new_str}` edits; each `old_str` must occur exactly once in the tab. Empty `old_str` is allowed only to initialize an empty tab. Never assume full-document replacement; for a large rework, patch section by section, sequentially.
5. **Discover specs with `spec_list`.** List the workspace's specs and filter titles client-side — that is the discovery path for specs. Reuse the existing spec for the feature; never create a duplicate.
6. **Spec titles are commit-form** — `feat: X`, `feat(scope): X`, or `fix(scope): X` — and spec status comes from the fixed enum `draft / in_review / rejected / approved / queued / building / released`. A newly created spec stays `draft`.
7. **Zero local artifacts.** This skill never creates or modifies any file in the user's repo or machine. Grounding notes, findings, and draft cases live in agent context only and never land anywhere except the finished Test plan tab.
8. **Mermaid, if used, is a fenced ` ```mermaid ` block** inside page-tab markdown. Write valid Mermaid; the product renders and validates it. A test plan rarely needs a diagram — add one only when a flow genuinely clarifies setup.

## Flow

Three phases, in order: **Ground → Brainstorm → Write**. Do not advance past a phase until its exit condition is met.

---

## Phase 1 — Ground

### 1a. Clarify intent

Derive up to THREE contextual clarifying questions. No pre-baked catalog — generate them from the user's phrasing plus what you find in the spec and repo. Each question must materially change the test plan's content; skip any already unambiguous from the request.

Generation algorithm:

1. Extract signals: feature domain keywords, risk indicators ("critical", "must", "compliance"), stakeholder hints ("QA", "release", "security"), explicit deliverables ("a11y", "rollback", "migration").
2. Cluster signals into candidate focus areas (max 4) ranked by relevance.
3. Detect missing dimensions: depth/rigor, environments in scope, risk emphasis, exclusion boundaries.
4. Choose questions from these archetypes:
   - Scope refinement — "Should the plan cover the integration touchpoints with X, or stay limited to this feature's own path?"
   - Risk prioritization — "Which of these risk areas need mandatory cases?"
   - Depth calibration — "Is this a pre-merge smoke list or a formal release gate?"
   - Boundary exclusion — "Should performance cases be explicitly out of scope this round?"
   - Scenario-class gap — "No recovery flows detected — are rollback / partial-failure paths in scope?"

Formatting rules: if presenting options, use a compact table with columns Option | Candidate | Why It Matters, A–E options maximum. Never ask the user to restate what they already said. Never invent speculative categories — if uncertain, ask "confirm whether X belongs in scope."

Defaults when the user cannot interact: depth Standard; focus the top 2 relevance clusters. After answers, if two or more scenario classes (Alternate / Exception / Recovery / Non-Functional) remain unclear, you MAY ask up to TWO targeted follow-ups with a one-line justification each. Five questions total, hard cap.

### 1b. Read the repo's real test setup

Read the **actual repository** with your own file tools (read, grep, glob). The working tree is the source of truth — do not rely on any indexed or external code graph, and do not assume a framework.

Establish, with file-level evidence:

- The test runner and libraries actually declared in the manifest/lockfile.
- Where tests live, how they are named, and how unit is split from integration.
- How this repo validates user-facing behavior against the running app: its e2e/browser tooling if any, or a documented manual pass if there is none.
- The commands that actually run each kind of test.

From this, derive which test **types are available here**. This list is the ceiling for the whole plan: a type with no runnable harness in this repo can only ever produce manual cases.

Optionally call `get_context` for workspace product context — useful grounding for personas, roles, and product vocabulary, but the working tree always wins on what is runnable.

### 1c. Read the spec and its Requirements

Locate the feature spec: `spec_list` in the resolved workspace, filter titles client-side, then `spec_read` the match to confirm its tabs and read the Requirements. Those requirement titles — verbatim, by plain title — are what every case must trace to.

If the spec or its Requirements do not exist yet (spec-qa running before spec-product), say so plainly — never hallucinate sections that are not there. Derive the requirement titles from the repo and the user's description, keep referencing them by plain title, and tell the user those titles will become the Requirements when spec-product runs.

### 1d. Pre-write consistency pass

Before deriving a single case, run a read-only quality pass over the spec's tabs. You are about to build a traceability map on top of these requirements — verify the foundation first. Never modify other tabs; report findings in chat only, and never write findings into the spec.

Build a requirements inventory: one stable key per requirement (its exact plain title), plus its acceptance criteria if present. Then run these detection passes across the Requirements and any sibling tabs (product, UX, engineering):

- **Ambiguity** — vague qualifiers (fast, robust, intuitive, secure) with no measurable criterion, and unresolved placeholders (TODO, TBD, ???). A requirement you cannot write an observable Expected result for is not testable as written.
- **Duplication** — near-duplicate requirements. Decide which title cases will trace to, and flag the pair.
- **Underspecification** — a verb with no object or no measurable outcome; acceptance criteria that do not match their requirement.
- **Inconsistency** — terminology drift between tabs (the same concept named differently), or requirements that contradict each other or the repo's actual behavior.
- **Coverage shape** — scenario classes with no requirements at all: if there are zero exception/error requirements for a feature that mutates state, that is a gap worth naming.

Assign severity: CRITICAL means a requirement is untestable or two requirements conflict — resolve with the user before writing cases (their fix belongs in the Requirements, via whoever owns that tab, not in your plan). MEDIUM/LOW findings get noted in one compact list and you proceed. Keep the report short, deterministic, and cited by tab and heading.

**Exit condition:** You know what the repo can actually run, you hold the verbatim requirement titles, and every CRITICAL finding is resolved or explicitly waived by the user.

---

## Phase 2 — Brainstorm

Work per requirement, in working notes only.

1. **Enumerate honest verification paths.** For each requirement, list the realistic ways to verify it, then keep the smallest set of cases that gives real confidence: the happy path plus the failure and permission edges the requirement implies. Coverage is measured in confidence, not case count.
2. **Choose the type per case** against what Phase 1 proved the repo can run:
   - Pure logic in isolation → **unit**.
   - Wired components or a data path → **integration**.
   - A full user path through the running app → **end-to-end**.
   - Behavior with no runnable harness in this repo → **manual**.
3. **Decide Automated? truthfully.** A case is `automated` only when the repo has a runner, a home, and a command for that type of test — proven in Phase 1, not assumed. Never label a case automated when this repo has no way to run it, and never document a test that does not exist as if it does. When in doubt, it is manual.
4. **Sweep scenario classes.** Across the whole set, check Primary, Alternate, Exception/Error, Recovery, and Non-Functional coverage. Where a class is intentionally out of scope (per Phase 1 answers), leave it out silently — do not pad. A non-functional requirement (a performance target, say) gets a case only if the repo can measure it; otherwise it is a manual case with an explicit measurement method.
5. **Consolidate.** Merge near-duplicate cases that verify the same aspect through the same path. If low-impact edge cases pile up, fold them into one case with multiple steps rather than five one-step cases. Prioritize by risk if the set grows past what a reviewer can actually read (roughly 40 cases is the smell threshold).
6. **Close the loop both directions.** Every requirement has at least one case — no exceptions. And every case maps to a requirement: a case with no requirement behind it is either evidence of a missing requirement (surface that to the user) or scope creep (cut it).
7. **Settle with the user.** Present the plan compactly — the case list grouped by requirement, each with its type and automated/manual label, plus anything you cut and why. Get agreement before writing.

**Exit condition:** The user has seen the full case set and coverage direction and agreed to it.

---

## Phase 3 — Write

Only clean, final, present-tense prose lands in Speqq. No working notes, no findings, no brainstorm residue.

### The section you own: Test plan

An enumerated list of test cases. Each case carries:

- **Test ID** — stable, `TC-1`, `TC-2`, … Never renumber existing IDs on a later edit; append.
- **Verifies** — the requirement it covers, by plain title, matching the Requirements verbatim.
- **Type** — unit / integration / end-to-end / manual.
- **Automated?** — automated or manual, stated explicitly.
- **Setup** — preconditions and fixtures.
- **Steps** — the actions taken.
- **Expected** — the observable result that passes the case.

Close the section with a one-line **coverage map**: requirement title → case IDs, covering every requirement, so no requirement is left uncovered and a reviewer can audit traceability at a glance.

### Worked example (illustrative — branch links)

Mirror this structure, not this stack. Requirement titles: *User can link a table row to a GitHub branch*, *A linked row shows its branch live status*, *Only editors and admins can change a row branch*.

| ID | Verifies | Type | Automated? | Setup | Steps | Expected |
|----|----------|------|-----------|-------|-------|----------|
| TC-1 | User can link a table row to a GitHub branch | unit | automated | Link handler with a mock branch input | Call the handler with a valid ref, then with a malformed ref | Valid ref returns the normalized link; malformed ref throws a validation error |
| TC-2 | User can link a table row to a GitHub branch | integration | automated | Seeded row, connected repo | Link the row to a branch, then re-read the row | The row persists the chosen branch and returns it on read |
| TC-3 | User can link a table row to a GitHub branch | end-to-end | manual | Running app, signed-in editor, a table with rows | Open a row, pick a repo and branch, save | The row shows the linked branch after reload |
| TC-4 | A linked row shows its branch live status | integration | automated | Linked row, stubbed upstream branch status | Render the row and read its status cell | The row displays the live status returned by the source; unreachable source shows an explicit unavailable state, not a stale value |
| TC-5 | Only editors and admins can change a row branch | integration | automated | One row, three actors: viewer, editor, admin | Attempt to change the branch as each actor | Viewer is denied; editor and admin succeed |

Coverage: *User can link a table row to a GitHub branch* → TC-1, TC-2, TC-3 · *A linked row shows its branch live status* → TC-4 · *Only editors and admins can change a row branch* → TC-5.

### Write sequence to Speqq

Write over MCP only — never local files. Add exactly one **Test plan** page tab. All calls sequential; wait for each before the next.

1. **Confirm the feature spec** you located in Phase 1 (`spec_list` + client-side title filter, then `spec_read`). Reuse it — one feature, one spec.
2. **Create the spec only if none exists.** If spec-qa runs before spec-product, `spec_create` a feature spec with a commit-form title (`feat: X` / `feat(scope): X` / `fix(scope): X`), status left at `draft`. If a spec already exists, do not create another.
3. **Add the Test plan tab.** `tab_create_page` with title `Test plan` and the finished markdown body — the case table plus the coverage map — as `content_markdown`. One call, one tab.
4. **If a `Test plan` tab already exists**, update it in place with `spec_markdown_tab_update` instead of creating a duplicate. Patch semantics: pass a `patches` array of `{old_str, new_str}` edits, each `old_str` occurring exactly once in the tab; use empty `old_str` only if the tab is empty. Preserve existing TC IDs; append new cases with fresh IDs and patch the coverage line to match.
5. **Checkpoint.** Show the user what landed — the tab, the case count, and the coverage line — and confirm before calling the work done.

**Exit condition:** The Test plan tab exists on the feature spec, matches the agreed plan, and the user has seen it.

---

## Quality checklist

Run this against the written tab before the final checkpoint. Fix failures — do not list them.

- Present tense, plain, production documentation. No filler, marketing, TODO, or diary notes.
- Lean: the case table and one coverage line, nothing padded.
- Every requirement maps to at least one case; each case names the requirement by its exact plain title, verbatim, so traceability lines up across the spec.
- No case exists without a requirement behind it.
- Test types and the automated/manual label reflect what this repo can actually run — no invented harness, no assumed framework, no test claimed that does not exist.
- TC IDs are stable and sequential; the coverage map matches the table exactly.
- Nothing was written to the user's filesystem, and no grounding or brainstorm notes leaked into the spec.
