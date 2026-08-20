---
name: scope-spec
description: Capture and explore a new piece of work before it becomes a spec. Read what exists, draft a rough one-page scope, and help the user shape and test the idea. Use it at the start of new work, to research an area, or when an idea is not ready to write up.
---

# Scope a spec

Capture what the user wants to do, then build on it. This is intake, not a finished document. Read what exists, draft a rough scope, and shape the idea until it's ready for `write-spec`. No spec is created here; the scope carries forward to `write-spec`.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.

## Steps

1. **Resolve the workspace.** Call `list_workspaces`. If there's one, use it. If there are several, ask which.
2. **Read what exists.** Call `get_context` for product context. Use `search` and `fetch` for related specs and code. Read the repo with your own file tools.
3. **Draft the scope.** One page: the problem, who it's for, the rough shape, and the open questions. Keep it short. Mark unknowns with `[NEEDS CLARIFICATION: question]`.
4. **Shape it with the user.** Ask one question at a time. Fold each answer into the draft.
5. **Track it if the user wants.** Run `add-to-queue` so the idea is on the queue.
6. **Hand off.** When the scope is ready, give the user the scope and the open questions, then point to `write-spec` to write the spec. `write-spec` records the scope to the spec's memory once the spec exists.

## FYI

- This is intake. Don't write a formal spec or requirements. That's `write-spec`.
- No spec exists yet, so nothing is written to a spec here. The scope and findings live in the conversation and carry into `write-spec`.
- Tools this skill uses: `get_context` for product context and personas, and `search` and `fetch` for related specs and code.
