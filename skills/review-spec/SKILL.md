---
name: review-spec
description: Review a spec for quality before work starts. Check that the spec is complete, testable, and clear, and flag the gaps. Use it after writing or updating a spec, or before building from one.
---

# Review a spec

Check a spec against best practices before anyone builds from it. Flag vague requirements, missing edges, and leaked implementation detail. Report findings. Don't rewrite the spec.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.
- A spec to review.

## Steps

1. **Resolve the spec.** Call `list_workspaces`, then `spec_list` and filter by title, or take the spec the user named.
2. **Read it.** Call `spec_read` for the Overview, the Requirements, and any other tabs.
3. **Check against the bar.** Confirm:
   - Each requirement is testable, in EARS, one behavior. No compound or vague rows.
   - Each requirement covers its edges: invalid, permission denied, empty, error.
   - Success criteria are measurable.
   - The Overview leads with what and why. No prose walls.
   - No `[NEEDS CLARIFICATION]` markers remain.
   - No implementation detail leaks into a requirement.
4. **Report.** List each finding: the row or section, the problem, and the fix. Rank by impact.
5. **Hand off.** Point to `write-spec` to apply the fixes.

## FYI

- Read-only. This skill writes nothing to the spec.
- Flag, don't fix. `write-spec` applies the changes.
