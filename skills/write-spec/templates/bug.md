# Bug spec template

A bug spec is one page tab. Write it lean. Follow `../references/style-guide.md`.

## Page

Lead with the failure. Then add these parts:

- **Symptom.** What the user sees, and the steps to reproduce it.
- **Root cause.** The confirmed cause, named and specific. If it is not confirmed, mark it a hypothesis.
- **Fix.** What changes, in one or two sentences, and the surfaces it touches.
- **Validation.** How you know it is fixed. A test or an observable check.

Keep it to what is proven.

## Table: Requirements (rows only if the fix adds behavior)

A pure fix needs no requirements. If the fix introduces new behavior, add it loose: one row that says what the new behavior does, what it does not, and its guardrails.
