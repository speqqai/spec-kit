---
name: review-code
description: Review code for quality and best practices after it's built. Check that the code is well built, not just that it matches the spec. Use it after implementing a spec, or when a user wants a code review.
---

# Review code

Check that code is well built. This is a quality review, separate from `check-drift`, which checks the code against the spec. Report findings and rank them by severity. Don't change the code without asking.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.
- A working tree to review. Speqq is optional here, used only to read the spec's requirements for context through `spec_read`.

## Steps

1. **Scope the review.** Read the changed files with your own tools. Read the repo's own standards and convention docs first, and treat them as the bar.
2. **Check the code.** Look for:
   - Correctness and edge cases.
   - The repo's own patterns, not imported ones.
   - Errors handled, no dead code, no leaked secrets.
   - Tests present for the behavior that needs them.
3. **Report.** List each finding: the file and line, the problem, and the fix. Rank by severity.
4. **Offer to fix.** Apply changes only after the user agrees.

## FYI

- Judge against the repo's own conventions, not a generic style.
- `check-drift` checks code against the spec. This skill checks code quality.
