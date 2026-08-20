# Installation

Speqq Spec-Kit is a set of [Agent Skills](https://agentskills.io) (`SKILL.md`, the open cross-agent standard) that turn your coding agent into a spec-driven planner whose specs live in Speqq instead of loose markdown files. One install covers every supported harness.

## Install as a plugin — Claude Code and Codex

One install delivers the skills and the session hooks.

**Claude Code:**

```bash
claude plugin marketplace add speqqai/spec-kit
claude plugin install spec-kit@speqq
```

**Codex CLI:**

```bash
codex plugin marketplace add speqqai/spec-kit
codex plugin add spec-kit@speqq
```

Start a new session after installing. On Claude Code the hooks are active immediately; on Codex, review and approve them once with `/hooks` — Codex never auto-trusts plugin hooks. The plugin also registers the Speqq MCP server, so there is no `mcp add` step — just sign in (`/mcp` on Claude Code, `codex mcp login speqq` on Codex), per [Connect Speqq](connect-speqq.md). Plugin skills are namespaced: `/spec-kit:write-spec` on Claude Code, `$spec-kit:write-spec` on Codex; plain-language requests trigger them the same as before.

## Install as folders — any harness

```bash
npx skills add speqqai/spec-kit
```

The `skills` CLI detects the coding agents you have set up, asks you to confirm which get the skills, and installs them all into each one you confirm. Each skill is a folder containing a `SKILL.md`; the agent loads it when the task matches the skill's description or when you invoke it by name.

Installs are project-level by default. Useful flags:

| Flag | Effect |
| --- | --- |
| `-g` | Install globally (user-level) instead of project-level — the skills follow you into every repo |
| `-a <agents>` | Install to named agents only, skipping the agent prompt |
| `-y` | Skip confirmation prompts |
| `--all` | Install every skill to every detected agent, no prompts |

## What gets installed

| Skill | What it does |
| --- | --- |
| `spec-product` | Creates the feature spec — Overview + testable Requirements with Given/When/Then acceptance criteria (no user stories) |
| `spec-ux` | Adds the Design tab — screens, four data states, flows, grounded in your repo's real design system |
| `spec-eng` | Adds System design + Implementation plan tabs (mermaid renders natively in Speqq) |
| `spec-qa` | Adds the Test plan tab — requirement-traceable TC cases with honest automated/manual labels |
| `spec-fix` | Writes bug specs — Overview / Root cause / Fix / Validation |
| `spec-implement` | Executes the Implementation plan, branch-per-feature, flips row statuses live |
| `spec-converge` | Reconciles code against the spec; appends drift as new plan steps |
| `spec-queue` | Files plan steps into the Speqq queue with dedup and priority |
| `spec-init` | Creates the spec shell, queue item, link, priority and in-progress status |
| `spec-research` | Reads what exists today and records the findings worth keeping |
| `spec-setup` | Connects Speqq — walks you through the MCP token and server registration, creates the credentials skeleton, and wires up the session hooks |
| `spec-update` | Updates an installed kit — plugin or folders — and reconciles the hooks after |
| `speqq-mcp-connect` | Checks the Speqq MCP connection and repairs it — registers a missing server, walks through re-authentication, says when a new session is needed |
| `spec-start` | Opens a session on a spec and records what the run is going after |
| `spec-pause` | Closes a session: where the work stands, and honest row statuses |
| `spec-snippet` | Appends one line to a spec's memory, on demand |
| `spec-resume` | Reads a spec's memory and reports where it stopped |

## Where skills land, per harness

Each harness reads skills from its own directory, and the installer writes to whichever ones it detects:

| Harness | Project install | Global install (`-g`) |
| --- | --- | --- |
| Claude Code | `.claude/skills/<name>/` | `~/.claude/skills/<name>/` |
| Codex CLI | `.agents/skills/<name>/` | `~/.agents/skills/<name>/` |

Cursor and Gemini CLI use their own directories; the installer prints the exact destination for each.

For the paths on your machine, read the installer output — it prints every file it wrote — or run:

```bash
npx skills list
```

If a harness does not appear in that output, check that harness's documentation for where it discovers skills, or re-run the installer from a directory where that harness is configured.

## After installing: connect Speqq

The skills store everything in a Speqq workspace over MCP — there is no `specs/` directory and no local state. Every skill runs a preflight and stops with connection instructions if the Speqq MCP server is not available. On Claude Code and Codex the plugin registers the server, so setup is just signing in — see [Connect Speqq](connect-speqq.md). On a folders-only install (Cursor, Gemini CLI, or `npx skills add`), register the server by hand from the same page.

## Updating

Ask your agent to **"update spec-kit"** — the `spec-update` skill detects how the kit was installed, checks the installed version against the latest, runs the update, and names what remains (a new session; `/hooks` re-trust on Codex when hooks changed).

By hand — plugin installs:

```bash
claude plugin update spec-kit@speqq
```

```bash
codex plugin add spec-kit@speqq
```

Folder installs:

```bash
npx skills update
```

`npx skills update` asks which scope to update; `-g` updates global installs and `-p` updates project installs without the prompt.

## Uninstalling

```bash
npx skills remove
```

Lists your installed skills and lets you pick the ones to remove — select the `spec-*` skills. Your specs are untouched — they live in Speqq, not on disk. If you had merged the session hooks, also delete their `SessionStart` entries from your harness config — see [Session hooks](hooks.md). If the command form differs in your CLI version, `npx skills --help` lists the current commands.

## Session hooks

The hook pack ships inside `spec-setup` — installing the skills puts the hook files on disk at `skills/spec-setup/hooks/`. Wired up, the hook injects three things at every session start, before you type anything: a connection-status line, the workspace's PRODUCT.md — the product brief — and the active work: open queue items, the active spec's memory tail, and the session identity. The agent starts already knowing what it is building and where the work stands.

Wiring is one merge into your harness config, and the hooks need no credentials by default — session start injects an orient instruction the agent executes over your existing MCP connection; a token is only for the opt-in rich mode and loss-point memory writes. Ask the agent to **"set up Speqq"** and `spec-setup` merges the entries, makes the scripts executable, and verifies it end to end — or do it by hand, per [Session hooks](hooks.md). The hooks run on Claude Code and Codex CLI today — tested on Codex 0.147.0 (approximate floors: skills 0.94.0+, session-start hooks 0.114.0+, the full pack 0.145.0+); Cursor and Gemini CLI session hooks cannot take plain-text stdout yet. Every skill works without the hooks — they make orientation automatic, not possible.

## Coming soon

Still on the roadmap: enforced status sync, phase auto-commit, and branch-guard hooks.
