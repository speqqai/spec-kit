---
name: write-spec
description: Write a feature spec in Speqq that frames the problem and the solution, then the requirements and tests. Set up the tracked queue item first, then write the Overview (objective, user, journeys, industry standard, current state, architecture, solution), the Requirements as parent rows with child build steps, and the tests. Use it when a user wants to spec a feature, write requirements, plan the build steps, add a test plan, or turn a scoped idea into a spec.
---

# Write a spec

Turn a scoped idea into a spec that frames the problem before the solution. A spec covers the objective, the user and their problem, the journeys, the industry standard, the current state, the architecture, the solution, the requirements, and the tests. Cover what the work needs and write each part lean; rationale and dead ends go to the spec's memory, not the body.

## Prerequisites

Confirm each, and set it up if it is missing, before writing. Do not just assert them.

- **Speqq MCP is connected.** If a Speqq call fails with a connection or authentication error, run `check-connection` first.
- **The work is tracked on the queue.** A queue item exists with a name, a description, status `in_progress`, and a branch name. If it is missing or incomplete, set it up in step 1: this is the anchor the spec attaches to.

## Steps

1. **Set up the tracked queue item.** Call `queue_read`. If no item tracks this work, `queue_add` one with a name and a description, then `queue_update_item` to set status `in_progress`. Derive the branch name from the commit-form title (`feat: user auth` becomes `feat/user-auth`) and record it on the item; `implement-spec` creates the actual git branch and links it later. Make the prerequisite true before writing anything.
2. **Resolve the spec.** Call `list_workspaces`, then `spec_list` and filter the title client-side. Reuse a match. Otherwise `spec_create` with a commit-form title (`feat: x`, `fix(scope): x`), then `queue_attach_document` to link it to the queue item.
3. **Record the scope to memory.** Append the scope carried in from `scope-spec` to the spec's memory with `spec_memory_append`, so the decisions behind the spec survive for the next session.
4. **Write the Overview.** One page tab that frames the problem and the solution, in order: objective, user, goal and problem, interfaces, core user journeys, industry standard and best practices, current state, architecture, solution and options. Default to the industry-standard product, UX, and technical pattern unless the user wants different; when you diverge, say why in one line. Cover what the feature needs: a real feature covers them all, a trivial change may fold or skip the product-framing parts and say which. Follow `templates/feature.md`, or `templates/bug.md` for a fix. Keep each part lean.
5. **Write the Requirements and their build steps.** One table tab, the single ledger. One parent row per requirement in EARS, covering the main event and the edges that matter. Under each requirement, write its build steps as child rows: what changes, the surfaces it touches, what it depends on, and how you know it is done (Changes / Surfaces / Depends on / Done when). Create each child step with `row_create` (`row_type` `child`, `parent_id` the requirement's row id): that is the only call that makes a child row. Use `row_create_batch` only to create several requirement parents at once, because it makes flat top-level rows and ignores `parent_id`.
6. **Write the Testing.** One table tab. One row per test, traced to a requirement by title.
7. **Attach the UX mockups.** For a UI feature, produce them from the project's Storybook when it has one, then attach the screenshots to the spec's queue item with `queue_create_image_upload` and `queue_attach_uploaded_image` so they show in the sidebar. Screenshots don't go in a doc tab.
8. **Report.** Give the spec title and id, the tabs written, the requirement and child-step counts, and the next step: `review-spec`.

## FYI

- The Overview frames the problem before the solution: objective, user, goal and problem, interfaces, core user journeys, industry standard, current state, architecture, solution and options. Comprehensive in coverage, lean in prose.
- Default to the industry standard for product, UX, and technical patterns unless the user asks for different.
- Follow `references/style-guide.md` for how to write the words, and `templates/feature.md` (or `templates/bug.md`) for the shape.
- Write sequentially to one spec. Parallel writes collide and drop content.
- `spec_markdown_tab_update` is patch based. Each `old_str` must occur exactly once.
- Rows: `row_create_batch` creates up to 50 flat top-level rows per call and ignores `parent_id`, `row_type`, and `status`, so use it for requirement parents and chunk larger sets. Child steps are made one at a time with `row_create` (`row_type` `child`, `parent_id`), the only call that nests a row and the only one that sets a child's status.
- Enums: priority `high`, `medium`, `low`. Row status `new`, `backlog`, `todo`, `in_progress`, `done`, `cancelled`.
- Write to Speqq over MCP only. Never write local files.
- Other tools: `get_context` for product context and personas, `get_product_context_template` for the skeleton the server returns for structured content, and the project's Storybook for UX mockups when it has one.
