---
name: write-spec
description: Write a feature spec in Speqq, covering the Overview, the Requirements, and the tests, with UX mockups attached. Write each requirement as a parent row and its implementation plan as child build steps under it, so the Requirements table is the single ledger. Use it when a user wants to spec a feature, write requirements, plan the build steps, add a test plan, or turn a scoped idea into a spec.
---

# Write a spec

Turn a scoped idea into a Speqq spec. Write only the sections the work needs, and write each requirement with its build steps as child rows beneath it, so the Requirements table is the single ledger. A spec is a lean index that points to detail, not the detail: background and decisions go to the spec's memory, not the body.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.
- A spec exists, or you create one. A queue item tracks it, or you file one after checking it is not already tracked.

## Steps

1. **Resolve the spec.** Call `list_workspaces`, then `spec_list` and filter the title client-side. Reuse a match. Otherwise `spec_create` with a commit-form title (`feat: x`, `fix(scope): x`).
2. **Record the scope to memory.** Once the spec exists, append the scope you carried in from `scope-spec` to the spec's memory with `spec_memory_append`. `scope-spec` hands the scope forward, and this is where it lands, so the decisions behind the spec survive for the next session.
3. **Choose the sections with the user.** Default to the Overview only. Add Requirements, Testing, or Design only when the work needs them.
4. **Write the Overview.** One page tab. What the feature does and who it is for, plus system design, technical design, and architecture. Follow the shape in `templates/feature.md`, or `templates/bug.md` for a fix. Keep it scannable.
5. **Write the Requirements and their build steps.** One table tab, and it is the single ledger. Write one parent row per requirement in EARS, covering the main event and the edges that matter. Under each requirement, write its implementation plan as child rows: the concrete steps to build it. Each child step states, concisely, what changes, the surfaces it touches, what it depends on, and how you know it is done (Changes / Surfaces / Depends on / Done when). Create each child step with `row_create` (`row_type` `child`, `parent_id` the requirement's row id): that is the only call that makes a child row. Use `row_create_batch` only to create several requirement parents at once, because it makes flat top-level rows and ignores `parent_id`.
6. **Write the Testing.** One table tab. One row per test, traced to a requirement by title.
7. **Attach the UX mockups.** Produce them from the project's Storybook when it has one, then attach the screenshots to the spec's queue item with `queue_create_image_upload` and `queue_attach_uploaded_image` so they show in the sidebar. Screenshots don't go in a doc tab.
8. **File a queue item if none tracks the spec.** Check `queue_read` first, then `queue_add` and `queue_attach_document`.
9. **Report.** Give the spec title and id, the tabs written, the requirement and child-step counts, and the next step: `review-spec`.

## FYI

- Follow `references/style-guide.md` for how to write the words, and `templates/feature.md` (or `templates/bug.md`) for the shape of the spec.
- Write sequentially to one spec. Parallel writes collide and drop content.
- `spec_markdown_tab_update` is patch based. Each `old_str` must occur exactly once.
- Rows: `row_create_batch` creates up to 50 flat top-level rows per call and ignores `parent_id`, `row_type`, and `status`, so use it for requirement parents and chunk larger sets. Child steps are made one at a time with `row_create` (`row_type` `child`, `parent_id`), the only call that nests a row and the only one that sets a child's status.
- Enums: priority `high`, `medium`, `low`. Row status `new`, `backlog`, `todo`, `in_progress`, `done`, `cancelled`.
- Write to Speqq over MCP only. Never write local files.
- Other tools: `get_context` for product context and personas in the Overview, `get_product_context_template` for the skeleton pattern the server returns for structured content, and the project's Storybook for UX mockups when it has one.
