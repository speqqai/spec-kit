---
name: spec-resume
description: >-
  Pick work back up on a spec. Reads the spec's MEMORY.md, its plan and its row
  statuses, and reports where the work stopped, what was already tried and
  abandoned, and what comes next. Use when a user returns to a spec, resumes
  after a break, picks up someone else's branch, or asks what they were working
  on and what is left. Read-only: it writes nothing.
---

# spec-resume

Answers one question: where did this stop, and what do I do next?

The spec's memory is the answer, and the reason it exists. A resumed session
that reads only the plan and the commits will happily redo an approach a
previous session already proved wrong.

## Steps

1. **Resolve the workspace and spec.** `list_workspaces`, then in order: a queue
   item the user picked; a spec the user named; the current git branch via
   `spec_orient`. Say which rung answered — a branch match is a strong signal, a
   fallback is a guess the user may want to correct.
2. **Read the memory FIRST.** `spec_memory_read` the spec, before the plan. The
   most recent lines are where the work stopped, and a pause note near the end
   usually states the state outright. **A spec with nothing recorded is a spec
   nobody has worked** — say so, and treat it as a start rather than a resume.
3. **Then read the plan and the ledger.** `spec_read` the Implementation plan
   and the Requirements rows with their statuses. Read the memory against them:
   the rows say what is done, the memory says what was tried.
4. **Read what you are building, if you need it.** `spec_orient` returns a
   `product_file` pointer to PRODUCT.md — worth reading when the next step
   involves a judgement call rather than a mechanical change.
5. **Report, leading with the state.** What the spec is for; where it stopped;
   what was tried and abandoned, with reasons; what is open; what you intend to
   do next. Then stop and let the user confirm — resuming into the wrong next
   step is the failure this skill exists to prevent.

## Worth surfacing

- **Anything already abandoned.** If the memory records an approach that was
  dropped, name it and its reason in the report. Not repeating a dead end is
  most of this skill's value.
- **Disagreements between the memory and the rows.** A row marked `done` with a
  later snippet saying it did not work means the row is wrong. Surface the
  conflict; do not quietly pick one.
- **How stale it is.** Stamps carry the date, so say when the last line was
  written. Work paused an hour ago and work paused last month deserve different
  amounts of re-reading.

## Worth being careful about

This skill writes nothing — not to the memory, not to the rows, not to the
user's machine. Recording that a session resumed is spec-start's job on a fresh
spec, and an ordinary snippet's job otherwise.
