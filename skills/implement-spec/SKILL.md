---
name: implement-spec
description: Build a feature spec's steps in the real codebase, using the spec as the live progress ledger. Orients from the product and the current branch, links the feature branch, works the child steps under each requirement while flipping each row's status as you go (in_progress, then done, with the commit recorded). Use when a user wants to build, implement, or execute a spec, start work on a feature, or resume work on an existing feature branch. Needs build steps written as child rows under the requirements by write-spec; stops and points there if none exist. Codebase-agnostic. Every command, convention, and gate comes from the repo you are in.
metadata:
  arguments:
    - name: spec
      description: The spec's id, short ref (e.g. SPQ-42) or URL.
---

# Implement a spec

Execute the build steps that `write-spec` wrote as child rows under each requirement, against the real working tree. The requirement rows and their child steps are the live progress ledger: row status flips replace checklist files, so there is no tasks file and no progress markdown. Git branches and commits are the implementation work, and they are the only things this skill writes to the user's machine.

## Before you start

- You can reach Speqq's tools. If a call fails because you are not signed in, tell the user to reconnect Speqq and stop.
- A spec whose requirements carry child build steps, written by `write-spec`. This skill executes plans; it does not invent them.

## Steps

1. **Orient.** Do these in order.
   - Call `list_product_spaces`. One: use it. Several: ask which. Pass it as `product_space` on every call.
   - Call `get_product` to learn the product, its users and its rules.
   - Call `get_current_work` with the spec (the `spec` argument, if given), your git branch (`git branch --show-current`) and the repo as owner/name (from `git remote get-url origin`). It tells you how the work was found (`resolved_by`), the spec's open rows and the specs you touched recently. Say how it was found in a short phrase, such as "from your branch".
   - Still no spec? List candidates with `list_specs` (filter `status: building` first), and ask the user to choose. Never guess.
2. **Read the spec, and stop if it has no build steps.** Call `get_spec`. Read the page and the table in full: each requirement row and, nested under it, its child build steps, with every row's id, title and status. Each child step carries Changes, Surfaces, Depends on and Done when in its description. If no requirement has child steps, STOP: tell the user this skill executes plans and does not invent them, and point to `write-spec`.
3. **Ground in the repo.** Read the working tree with your own file tools. Read the repo's instruction and convention documents wherever they live. Find the validation gates in the repo itself: its manifest scripts, CI configuration, makefiles and contributor docs. The gates you run are the repo's own commands, never assumed.
4. **Check the worktree.** Run `git status`. If the tree is dirty, show the user the exact state and ask how to proceed. Never stash, discard or commit pre-existing changes without an explicit instruction.
5. **Verify the plan still fits.** Check each child step's Surfaces against the tree as it is now, and the dependency order. If reality has drifted (surfaces gone, work already done, steps stale), stop and show the mismatch. Small drift: propose a fix to the step's description and apply it with `update_spec_rows` only with the user's approval. Large drift: point to `check-drift` or `write-spec`.
6. **Settle the branch.** If `get_current_work` found the spec from your branch, you are already on it. Otherwise derive the name from the commit-style spec title: `feat: user auth` becomes `feat/user-auth`. Never a trunk name (main, master, dev, develop, release/*). If the branch already exists, reuse it.
7. **Present the run and get a go-ahead.** Show the requirement order, the child steps under each, the gates that will run, and the rows that will flip. Do not write to Speqq or create the branch before the user agrees.
8. **Start the run.** One call at a time, in this order:
   - `git checkout -b <branch>` from the agreed base (or check out the existing branch).
   - Link the branch to the spec: `update_spec` with `branch` (add `branch_repository` as owner/name when several repositories are connected). This is what lets a later session find the spec from the branch alone. Also link the requirement rows this run delivers: `update_spec_rows` with `rows[].branch`.
   - Set the spec's status to `building` with `update_spec`, if it is not already.
9. **Work the step loop.** Go requirement by requirement, finishing each requirement's child steps before the next. Honor every Depends on. Steps that touch the same files run strictly in order. For every child step:
   - **Flip it to in progress first.** Before writing any code, `update_spec_rows` with `rows[].status` of `in_progress`. The ledger leads the work.
   - **Do the work.** The narrowest change that satisfies the step's Changes on its named Surfaces, in the repo's own patterns. Follow the repo's test convention.
   - **Validate.** Run the gates the repo defines: the step-relevant ones after the change, the full set at the end of each requirement. A red gate blocks the step. Fix and re-run. Never advance past a failure, and never flip a row to `done` over one.
   - **Commit.** Use a commit message scoped like the spec title. Capture the SHA.
   - **Flip it to done and record the commit.** `update_spec_rows` with `status: done`, and add `Completed in commit <sha>` as a last line of the row's description (read the current text first and carry it; the new description replaces the old). If the table has a commit column, write the SHA there with `rows[].fields` instead.
   - **Close the requirement.** When every child step is `done` and the requirement's acceptance holds, flip the requirement row to `done`.
   - **Report.** One short note per step: step, what changed, gate result, commit SHA, rows flipped.
10. **Handle failure or interruption.** Stop a sequential run at the failing step. Report the error with context and next steps, and leave the ledger honest: started rows stay `in_progress`, and nothing is flipped `done` on a hunch. If the user approves extra work mid-run, add it as a child step with `create_spec_rows` (`parent` is the requirement's row id or ref, `status: todo`) rather than quietly widening a step.
11. **Finish.** When the steps are done, or the user stops:
    - Run the repo's full gate set one last time. Confirm each step's Done when holds and that row statuses match reality: no row is `done` whose behavior you cannot observe.
    - Report: requirements and steps completed, commits with SHAs, gates run and their results, and every row that is not `done`, with why.
    - Ask the user how to handle the remaining rows (leave, `todo`, `cancelled`) and apply it with `update_spec_rows`. Suggest moving the spec to `released` with `update_spec` only if the work is shipped, and set it only on a yes.

## FYI

- **No local state.** Create no pointer file, notes file or progress file. Working notes live in the conversation. Branching, editing source and committing are the deliverable, not state.
- **Row statuses.** `new`, `backlog`, `todo`, `in_progress`, `done`, `cancelled` or `duplicate`. Never invent a value; put an unmappable label in the description.
- **Spec statuses.** `draft`, `in_review`, `approved`, `building` or `released`, set with `update_spec`.
- **Nesting.** Rows nest one level: a step sits under a requirement, never under another step.
- **Sequential writes.** Make writes to one spec one after another. Parallel writes collide and silently drop.
- **Page edits.** Change the spec's page only for an amendment the user approved, with `update_spec` `page.edits` (each `old_str` must occur exactly once) or `page.append`. Never use the page to track progress.
- **Commit-style titles.** Spec titles read `feat: X`, `feat(scope): X` or `fix(scope): X`; the branch name derives from them and is never a trunk name.
