# Installation

Speqq Spec-Kit is a set of eight [Agent Skills](https://agentskills.io) (`SKILL.md`, the open cross-agent standard) that turn your coding agent into a spec-driven planner whose specs live in Speqq instead of loose markdown files. One install covers every supported harness.

## Install

```bash
npx skills add speqqai/spec-kit
```

The `skills` CLI detects the coding agents you have set up, asks you to confirm which get the skills, and installs all eight into each one you confirm. Each skill is a folder containing a `SKILL.md`; the agent loads it when the task matches the skill's description or when you invoke it by name.

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

## Where skills land, per harness

Each harness reads skills from its own directory, and the installer writes to whichever ones it detects. In Claude Code that is `.claude/skills/<name>/` in the project, or `~/.claude/skills/<name>/` with `-g`.

For the exact paths on your machine, read the installer output — it prints every file it wrote — or run:

```bash
npx skills list
```

If a harness does not appear in that output, check that harness's documentation for where it discovers skills, or re-run the installer from a directory where that harness is configured.

## After installing: connect Speqq

The skills store everything in a Speqq workspace over MCP — there is no `specs/` directory and no local state. Every skill runs a preflight and stops with connection instructions if the Speqq MCP server is not available. Set it up once: see [Connect Speqq](connect-speqq.md).

## Updating

```bash
npx skills update
```

Refreshes installed skills to their latest published versions. It asks which scope to update; `-g` updates global installs and `-p` updates project installs without the prompt.

## Uninstalling

```bash
npx skills remove
```

Lists your installed skills and lets you pick the ones to remove — select the eight `spec-*` skills. Your specs are untouched — they live in Speqq, not on disk. If the command form differs in your CLI version, `npx skills --help` lists the current commands.

## Coming soon

Two additions are on the roadmap: per-harness hook packs (session context injection, enforced status sync, phase auto-commit, branch guard) and one-install plugins for Claude Code and Codex that bundle the skills together with the Speqq MCP connection.
