---
name: write-spec
description: Write a spec in Speqq for any kind of work, a feature, a bug, an A/B test, or research. Confirm the type first, then let its template drive the body. Get context, confirm the scope, research the area, write, and validate in a loop. Use it when a user wants to spec a feature, write up a bug, plan an A/B test, capture research, write requirements, or turn a scoped idea into a spec.
metadata:
  arguments:
    - name: type
      description: The kind of work, one of feature, bug, abtest or research.
---

# Write a spec

A spec frames the work before you build it, and stays the record of it afterward. This is one flow for four kinds of work: a feature, a bug, an A/B test, or research. You confirm the type first, and the template for that type drives what you write. Keep every part lean, and keep it to the output: what the work is and does.

## Before you start

- You can reach Speqq's tools. If a call fails because you are not signed in, tell the user to reconnect Speqq and stop.
- Know the product space. Call `list_product_spaces`. One: use it. Several: ask which. Pass it as `product_space` on every call.
- Check whether a spec for this work already exists. Call `list_specs` and match by title, or take the spec the user named. Reuse it. Create a new one only when none fits.

## Steps

Confirm the type, get context, and confirm the scope first. Then steps 4 to 7 are a loop: understand the current state, research, write, and validate. If the spec does not validate, go back to step 4 and refine.

1. **Confirm the type.** If `type` was passed, use it. Otherwise ask the user which kind of work this is. Then open the matching template. It defines the body you will write.
   - Feature: `templates/feature.md`
   - Bug: `templates/bug.md`
   - A/B test: `templates/abtest.md`
   - Research: `templates/research.md`
2. **Get context.** Call `get_product` to learn who the product serves and how this work fits.
3. **Confirm the scope.** Before you research, put your open questions to the user, one at a time, and fold in the answers. Do not assume the scope.
4. **Understand the current state.** Read the code with your own file tools. Use `search`, `code_search` and `knowledge_graph_query` for related specs, docs and code the product space knows about.
5. **Research the area.** Learn the best practices for this, including how other products and domains solve it well.
6. **Write.** Write the body the template defines.
   - New spec: `create_spec` with a commit-style title such as `feat: user auth`, the page in Markdown, and `branch` when the work already has a feature branch.
   - Existing spec: `update_spec` with `page` (`replace`, `append`, or exact-text `edits`).
   - Requirements and tests go in the spec's table: `create_spec_rows`, up to 50 per call. Each row has a title, and optionally `description`, `priority`, `status` and `fields` (the table's own columns, by column title). Nest a sub-row with `parent` (a top-level row's id or ref).
7. **Validate.** Read the spec back with `get_spec`. Check it is complete, accurate, and something you can build from. If it is not, go back to step 4 and refine.

## FYI

- The spec is what the user reads. Resolve open questions rather than parking them in the spec. Keep your research notes in the conversation unless the user wants them in the spec.
- The template drives the body. The flow is the same for every type; what changes is the template you follow.
- Write to Speqq, never to local files.
- Spec status is one of `draft`, `in_review`, `approved`, `building` or `released`. A new spec is a draft. Change it with `update_spec` only when the user asks.
- Follow `references/style-guide.md` for the words.
- Keep it loose. Write what the work needs now and let the spec grow as the build proves what it needs.
- Default to the industry standard for product, UX, and technical patterns unless the user asks for different.
- Write one spec at a time, and make writes to one spec one after another, not in parallel. Parallel writes collide and drop content.
