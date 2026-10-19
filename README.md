# Speqq Spec-Kit

**Spec-driven development for coding agents — with every spec living in Speqq, not in loose markdown files.**

Speqq Spec-Kit is a set of [Agent Skills](https://agentskills.io) (`SKILL.md`, the open cross-agent standard) that turn Claude Code, Codex CLI, Cursor, or Gemini CLI into a spec-driven planner. It follows the lineage of GitHub's spec-kit with one fundamental difference: every artifact lands in a Speqq workspace over MCP — live collaboration, a real work queue, row-level execution status. No `specs/` directory. No state files. Zero local state.

## What spec-driven development in Speqq means

Each spec is a live Page and Table in a Speqq workspace. The Page explains the problem, design, and verification. The Table tracks requirements and their child build steps. Product and engineering teammates can read and update the same plan the agent uses, while code remains in Git.

The kit uses the open [Agent Skills](https://agentskills.io) format and Speqq MCP. It adds no local planning files or proprietary development dependencies to your repository. When a deliverable needs a separate plan, create a child spec rather than another tab.

## Get started

### 1. Install the plugin

One install delivers the skills and the session hooks. Claude Code:

```bash
claude plugin marketplace add speqqai/spec-kit
claude plugin install spec-kit@speqq
```

Codex CLI:

```bash
codex plugin marketplace add speqqai/spec-kit
codex plugin add spec-kit@speqq
```

Start a new session after installing; on Codex, approve the hooks once with `/hooks`. For Cursor, Gemini CLI, or a folders-only install, use `npx skills add speqqai/spec-kit` via [skills.sh](https://skills.sh) — see [docs/installation.md](docs/installation.md).

### 2. Sign in to Speqq

The plugin registers the Speqq MCP server for you — no `mcp add` step and no token. Just sign in once and finish the browser login:

- **Claude Code** — run `/mcp` and authenticate `speqq`.
- **Codex** — run `codex mcp login speqq`.

On Cursor, Gemini CLI, or a bearer-token setup for service accounts, register the server by hand — see [docs/connect-speqq.md](docs/connect-speqq.md).

### 3. Write your first spec

Ask your agent: "Write a feature spec for PDF report export." `write-spec` creates a spec with one Page and one Table. The Page holds the objective, context, design, and verification plan. The Table holds requirement rows and child build steps. Related work that needs its own Page and Table becomes a child spec.

## Skills

| Skill | Purpose |
| --- | --- |
| `scope-spec` | Settle the scope and create or find the spec and queue item. |
| `write-spec` | Write a feature, bug, experiment, or research spec in the seeded Page and Table. |
| `review-spec` | Check that the spec is clear, testable, and ready to build. |
| `add-to-queue` | File planned work in the workspace Queue without duplicates. |
| `implement-spec` | Build the child steps under requirement rows and record progress in Speqq. |
| `check-drift` | Compare the code with the spec and append uncovered work as child steps. |
| `review-code` | Review the implementation against the spec and repository conventions. |
| `start-work`, `pause-work`, `resume-work`, `add-memory` | Keep the current work and its append-only memory available across sessions. |
| `check-connection`, `update-kit` | Repair the MCP connection or update the plugin. |

`spec_create` returns the IDs of the spec's Page and Table. Agents edit those two surfaces through the Specs MCP tools. They create a child spec for a separate body of content; they do not create extra tabs.

## Workflow

1. Scope the work and link its queue item to a spec.
2. Write and review the Page, requirement rows, and child build steps.
3. Implement each step against the repository, recording status and evidence in Speqq.
4. Check drift and review code until the behavior and spec agree.
5. Use the memory skills to hand work between sessions.

The plugin keeps planning data in Speqq. Git branches and commits hold the code changes.

## Shared memory

When a repository has `.speqq` at its root with `memory: @handle`, the tokenless session hooks prompt the agent to read that shared Knowledge memory at the start of a session and write progress or a durable handoff as context fills. The plugin also registers `speqq-knowledge` at `https://speqq.com/mcp/knowledge`; authenticate it in the same harness as the Specs connection. The agent sends `memory_read` and `memory_write` over its own MCP connection. Spec-specific `MEMORY.md` remains available for the work timeline.

## Zero local state

The skills write nothing to your machine except the deliverable itself — the branches and commits `implement-spec` produces.

- **No `specs/` directory.** Specs live in Speqq, where your team already works.
- **No task or progress files.** Requirement rows are the ledger; status flips replace `[x]` markers.
- **No pointer files.** The active spec resolves from Speqq-side data — the queue item you picked, the spec list, the current git branch matched against row branch links — never from a file on disk.
- **Drafts never touch disk.** Grounding notes, options, and clarification queues live in conversation context; only clean, final prose lands in the spec.

The result: resume work from any machine or session, nothing to merge or go stale, and teammates watch progress live because the spec is the dashboard.

## Supported harnesses

The plugin registers `https://speqq.com/mcp/specs` for planning and `https://speqq.com/mcp/knowledge` for shared memory. How they are registered depends on the harness.

| Harness | How Speqq MCP is set up |
| --- | --- |
| Claude Code | Registered by the plugin — just sign in with `/mcp` |
| Codex CLI | Registered by the plugin — just sign in with `codex mcp login speqq` |
| Cursor | Register by hand: MCP server entry in `mcp.json` (project or global) |
| Gemini CLI | Register by hand: MCP server entry in the settings file |

## Roadmap

Planned, not yet shipped:

- **Deeper hook packs** — enforced status sync, phase auto-commit, and a branch guard. Session context injection already ships: the plugin carries session hooks for Claude Code and Codex CLI — see [docs/hooks.md](docs/hooks.md).

## Documentation

- [docs/installation.md](docs/installation.md) — installing, updating, and removing the skills, per harness
- [docs/connect-speqq.md](docs/connect-speqq.md) — connecting the Speqq MCP server, per harness, with troubleshooting
- [docs/hooks.md](docs/hooks.md) — the session hooks: what they inject, the invariants, the credentials bridge
- [docs/workflow.md](docs/workflow.md) — the spec-driven workflow end to end

## License

MIT
