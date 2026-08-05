---
name: spec-snippet
description: >-
  Append one line to a spec's MEMORY.md, on demand. Use when a user says to
  record, note, remember, log, or jot something down about the work — or when
  they want to add to what was already recorded. Records exactly what they mean,
  in the agent's own words, with the time stamped by the server. For ending a
  session use spec-pause; for starting one use spec-start.
---

# spec-snippet

One line, appended. That is the whole skill.

A spec's memory is a log of what happened while it was built, written as work
happens rather than reconstructed afterwards. Most lines get written by the
agent doing the work. This is the one the user asks for.

## Steps

1. **Resolve the spec.** Queue item, named spec, or current branch via
   `spec_orient`. Ask if nothing resolves — a snippet on the wrong spec is a
   line nobody can trace.
2. **Work out what to record.** If the user said what to record, record that. If
   they asked vaguely — "note where we are", "add something about the bug" —
   write what you know from the session and show it before appending. Never
   invent something that did not happen to fill the line.
3. **Write it as one line.** `spec_memory_append` with the text only. The server
   stamps the time; you never pass one.
4. **Confirm.** Report the stamped line back so the user sees what landed.

## Writing the line

Lead with what happened, past tense — *Built…*, *Decided…*, *Dropped…*,
*Found…*, *Fixed…*. The verb carries the meaning a category label would, and it
costs nothing to choose.

One thing per line. If it needs an "and", it is two snippets — append twice.

Say **why** when the why is the point. An abandoned approach recorded without
its reason is an invitation to try it again.

Name the thing. *Dropped the webhook handler* beats *dropped that approach*.

Write for someone who was not here, because that is exactly who reads it.

There is no category to choose and nothing validates the wording — the sentence
is the whole record. Multi-line text is folded onto one line, and empty text is
refused.

## Worth being careful about

- **Nothing is ever edited.** The memory is append-only: a correction is a new
  line saying what changed, not a rewrite of the old one. If the user asks to
  fix an earlier snippet, append the correction and say why it works that way.
- **More than one is fine.** If the user has several things to record, append
  several — one line each, rather than one line carrying everything.
