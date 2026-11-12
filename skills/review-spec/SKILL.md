---
name: review-spec
description: Review a spec for quality before work starts. Check that the spec is complete, testable, and clear, and flag the gaps. Use it after writing or updating a spec, or before building from one.
metadata:
  arguments:
    - name: spec
      description: The spec's id, short ref (e.g. SPQ-42) or URL.
---

# Review a spec

Check a spec against best practices before anyone builds from it. Flag vague requirements, missing edges, and leaked implementation detail. Report findings. Don't rewrite the spec.

## Before you start

- You can reach Speqq's tools. If a call fails because you are not signed in, tell the user to reconnect Speqq and stop.
- A spec to review.

## Steps

1. **Resolve the spec.** Use the `spec` argument, or the spec the user named. If you only have a title, call `list_product_spaces`, then `list_specs`, and match by title. Ambiguous: show the candidates and ask.
2. **Read it.** Call `get_spec` for the page and every table. Add `parts: ["links"]` to see how rows link to other items. Call `list_spec_comments` to see open discussion.
3. **Check against the bar.** Confirm:
   - Each requirement is testable, in EARS, one behavior. No compound or vague rows.
   - Each requirement covers its edges: invalid, permission denied, empty, error.
   - Success criteria are measurable.
   - The page leads with what and why. No prose walls.
   - No `[NEEDS CLARIFICATION]` markers remain.
   - No implementation detail leaks into a requirement.
4. **Report.** List each finding: the row or section, the problem, and the fix. Rank by impact.
5. **Offer to leave the findings as a comment.** If the user agrees, post a short summary with `create_spec_comment` (or on one row, with `row`). Mention people only when the user names them.
6. **Hand off.** Point to `write-spec` to apply the fixes.

## FYI

- Read-only. This skill changes nothing in the spec. The one write it may make is a comment, and only with the user's agreement.
- Flag, don't fix. `write-spec` applies the changes.
