---
name: check-drift
description: Reconcile the actual codebase against a feature spec in Speqq. Reads the spec's requirements and the child build steps under them, honestly assesses what the code delivers today, flips genuinely done rows to done, and appends the remaining gap as new child steps under the relevant requirement, never rewriting finished rows and never duplicating steps that already cover the gap. Use when a user asks to converge, reconcile code against a spec, check drift, mark what is done, or find what is left to build. Append-only and codebase-agnostic. It assesses the present working tree, not git history, and changes no application code.
metadata:
  arguments:
    - name: spec
      description: The spec's id, short ref (e.g. SPQ-42) or URL.
---

# Check drift

Reconcile the codebase against a feature spec. Read the spec's requirements and the child build steps under each as the source of intent, mark genuinely done work done, and append the remaining gap as new child steps for `implement-spec` to complete. The only writes land in the spec (status flips and appended child steps). This skill changes no application code, runs no git comparison, and assesses the present state of the working tree.

## Before you start

- You can reach Speqq's tools. If a call fails because you are not signed in, tell the user to reconnect Speqq and stop.
- A feature spec with requirements that carry child build steps.

## Steps

1. **Orient.** Call `list_product_spaces`. One: use it. Several: ask which. Then resolve the spec in this order and stop at the first that answers:
   - The `spec` argument or the spec the user named. Call `get_spec`; if you only have a title, call `list_specs` and match by title.
   - Your current branch. Call `get_current_work` with `branch` (`git branch --show-current`) and `repo` (owner/name from your git remote). Use the spec it returns.
   - Specs with status `building` from `list_specs`. One: confirm it with the user. Several: ask which.
   - Otherwise show a short list (title, status) and ask.
2. **Read the spec, and stop on missing intent.** Call `get_spec` for the page and the table: every requirement row, its child build steps, and current statuses. Steps a prior check-drift pass appended are existing intent and feed the dedup gate. If there are no requirements, STOP and point to `write-spec`. If no requirement has child build steps, STOP and point to `write-spec` for the steps. Never invent intent, and never give a partial assessment.
3. **Read the code and build the intent inventory.** Call `get_product` for context. Use your own file tools (read, grep, glob) on the working tree. Bound the assessment to the files and surfaces the child steps name, plus a keyword search for the concepts each requirement describes. Do not infer scope beyond what the spec defines. The result is an inventory with one key per requirement and child step, and a map of the real files in scope.
4. **Assess each item, with evidence.** Record exactly one verdict per item, each citing the file or surface you saw:
   - **done**: the behavior is present and observably satisfies the item. A requirement is done only when its acceptance holds (its child steps are done and its behavior is observable). A child step is done only when its Done when condition holds in the code as it stands.
   - **partially met**: work exists but falls short. Name what exists, where, and what is missing.
   - **unmet**: the work is absent.
   - Never mark aspirationally. If you did not see it in the code, it is not done.
5. **Classify and rank each gap.** Classify anything not fully done as `missing`, `partial`, `contradicts` (the code conflicts with stated intent or a repo standard; read the repo's instruction and convention docs and treat them as governing), or `unrequested` (code the spec does not call for, surfaced for awareness; check drift never deletes code, it appends a step to review, justify or remove it). Set severity: CRITICAL (violates a governing repo standard, or blocks a high-priority requirement's baseline behavior), HIGH (missing or partial on a core requirement or step), MEDIUM (partial on a secondary requirement, or an unjustified unrequested addition), LOW (polish and low-risk leftovers).
6. **Run the dedup gate.** Before drafting any new step, re-read the existing child steps, including those a prior pass appended. A gap already covered by an existing step, done or pending, gets no new step; the existing step is the work item.
7. **Report the delta and get a go-ahead.** Show a compact table: finding, gap type, severity, source requirement or step, and the evidence. Add counts: items checked, verdicts by kind, findings by type and severity, rows to flip, steps to append. Get the user's go-ahead before any write. Zero findings means zero writes: report that the spec has converged and recommend `review-code`.
8. **Flip genuinely done rows.** Make writes one at a time. For each requirement or step row whose verdict is done, call `update_spec_rows` with `rows[].status` of `done`. Change nothing else on the row. Leave rows already `done` alone. Leave partially met rows at their status; their gap becomes an appended step.
9. **Append the gap as child steps.** Order CRITICAL and HIGH first, contradictions before the rest. Each new step is concrete in the `write-spec` step form (Changes, Surfaces with real paths, Depends on, Done when as observable behavior) and names its gap type. Call `create_spec_rows` with `rows[].parent` set to the requirement's row id or ref, a `title`, a `description` and `status: todo`. Rows nest one level, so a step attaches to a requirement, never to another step. A gap that needs a brand-new requirement: create the top-level row first (no `parent`), then its steps under it in a second call.
10. **Leave the spec status alone** unless the user asks. Row status flips are how check drift records progress.
11. **Report the outcome.** Converged or gap appended, with the spec title and id. Counts of what you checked and found. Writes made: rows flipped, steps appended and under which requirement. The next step: run `implement-spec` to complete the appended steps; a later check-drift pass should find fewer items.

## FYI

- **Append-only.** Never rewrite, renumber, reorder or delete finished rows, existing steps or existing requirements, including steps a prior pass appended. When the code already satisfies everything, write nothing.
- **No local state.** Create or change no file on the user's machine. Read-only git commands like `git branch --show-current` are fine.
- **Not a diff tool.** It assesses the present working tree, not history or a branch comparison.
- **Sequential writes.** Make writes to one spec one after another. Parallel writes collide and silently drop.
- **Row statuses.** `new`, `backlog`, `todo`, `in_progress`, `done`, `cancelled` or `duplicate`. Never invent a value; put an unmappable label in the description.
- **Spec statuses.** `draft`, `in_review`, `approved`, `building` or `released`.
- **Evidence in text.** To record a landing commit as evidence, put it in the step's description or a custom column (`rows[].fields`), not in a made-up field.
- **Quality gate.** Before you finish, check in conversation: every verdict cites a file you read, and nothing is done aspirationally; no appended step duplicates an existing one, and each traces to its requirement and gap type with real surfaces and an observable Done when; nothing existing was rewritten, and a converged run wrote nothing; the delta was agreed before the first write; no file was created on the user's machine.
