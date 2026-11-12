---
name: scope-spec
description: Capture and explore a new piece of work before it becomes a spec. Read what exists, draft a rough one-page scope, and help the user shape and test the idea. Use it at the start of new work, to research an area, or when an idea is not ready to write up.
---

# Scope a spec

Capture what the user wants to do, then build on it. This is intake, not a finished document. Read what exists, draft a rough scope, and shape the idea until it's ready for `write-spec`. No spec is created here; the scope carries forward to `write-spec`.

## Before you start

- You can reach Speqq's tools. If a call fails because you are not signed in, tell the user to reconnect Speqq and stop.

## Steps

1. **Find the product space.** Call `list_product_spaces`. One: use it. Several: ask which.
2. **Read what exists.** Call `get_product` for the product, its users and its rules. Use `search` and `read_document` for related specs and docs, `code_search` for code, and `list_specs` to see what is already specced. Read the repo with your own file tools.
3. **Draft the scope.** One page: the problem, who it's for, the rough shape, and the open questions. Keep it short. Mark unknowns with `[NEEDS CLARIFICATION: question]`.
4. **Shape it with the user.** Ask one question at a time. Fold each answer into the draft.
5. **Hand off.** When the scope is ready, give the user the scope and the open questions, then point to `write-spec` to write the spec.

## FYI

- This is intake. Don't write a formal spec or requirements. That's `write-spec`.
- No spec exists yet, so nothing is written to Speqq here. The scope and findings live in the conversation and carry into `write-spec`.
