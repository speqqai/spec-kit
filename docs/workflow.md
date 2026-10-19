# Workflow

Spec-Kit keeps plans and progress in Speqq. A spec has one Page and one Table. Its Page carries the objective, user journeys, architecture, and verification plan. Its Table carries top-level requirements and child build steps. A separate body of work becomes a child spec, with its own Page and Table.

## Start a new piece of work

1. Run `scope-spec` to clarify the outcome and connect the work to a Speqq queue item.
2. Run `write-spec` with the feature, bug, A/B test, or research template. `spec_create` seeds both tabs and returns their IDs. Write the Page sections into the existing Page and the requirement rows into the existing Table.
3. For a feature, give each requirement its concrete child build steps. Each child row states Changes, Surfaces, Depends on, and Done when.
4. Run `review-spec` and resolve gaps before implementation.

## Build and reconcile

`implement-spec` reads the Page, the requirement rows, and their child steps. It works the steps in dependency order, using the repository's existing conventions and gates, and records honest row statuses and commit evidence. `check-drift` compares the current code with those requirements and appends uncovered work as child steps. `review-code` checks the result against the spec and the repository.

Use `add-to-queue` when the plan needs queue items. Use `start-work`, `pause-work`, `resume-work`, and `add-memory` to carry the work between sessions. The spec's append-only memory records decisions and evidence; its Page and Table remain the readable plan and progress ledger.

## When a spec grows

Keep the one Page and one Table intact. Organize related narrative under Page headings. Add sub-items beneath requirement rows for executable work. Create a child spec with `spec_create(parent_id=...)` when a separate deliverable needs its own plan or owner.
