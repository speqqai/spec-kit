# Bug spec template

A bug spec is one page tab. Write it lean. Follow `../references/style-guide.md`.

## Overview (page tab)

Lead with the failure. Then add these parts:

- **Symptom.** What the user sees, and the steps to reproduce it.
- **Root cause.** The confirmed cause, named and specific. If it is not confirmed, mark it a hypothesis.
- **Fix.** What changes, in one or two sentences, and the surfaces it touches.
- **Validation.** How you know it is fixed. A test or an observable check.

Keep it to what is proven. Investigation notes and dead ends go to the spec's memory, not here.

## Requirements (table tab, only if the fix adds behavior)

A pure fix needs no requirements. If the fix introduces new behavior, add it in EARS, one row each.
