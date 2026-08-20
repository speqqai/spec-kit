---
name: update-kit
description: Update an installed Spec-Kit and reconcile what the update touched. Use when a user asks to update spec-kit or the Speqq skills, check whether a newer version exists, or after an update is announced. Detects the install channel (plugin or plain skill folders), reports installed vs latest version, runs the update commands the harness allows and hands the user the rest, and names the post-update steps, including the `/hooks` re-trust on Codex when hooks changed.
---

# Update the kit

Update the kit the way it was installed, then name what still has to happen for the update to take effect. Never guess the channel or a version: detect both, and report `unknown` over inventing either.

## Prerequisites

- Speqq MCP must be connected. If a Speqq call fails with a connection or authentication error, run `check-connection` first.

## Steps

1. **Detect the install channel.**
   - Plugin: `claude plugin list` shows `spec-kit@speqq` (Claude Code); `codex plugin list --json` shows it (Codex).
   - Folders: `spec-*` skill directories under `~/.claude/skills/` or `.claude/skills/` (Claude Code), `~/.agents/skills/` or `.agents/skills/` (Codex) with no plugin entry.
   Both can coexist. If they do, say so and update both.
2. **Check versions.** Installed: the version in the plugin listing, or `./VERSION` at the repo root for a folder install (older folder installs predate the marker; report that plainly). Latest: refresh the marketplace first (`claude plugin marketplace update speqq` / `codex plugin marketplace upgrade`), then read the listing. If installed already equals latest, report that and stop.
3. **Update.**
   - Claude Code plugin: `claude plugin update spec-kit@speqq`
   - Codex plugin: `codex plugin add spec-kit@speqq`. Re-adding installs the refreshed version.
   - Folders: `npx skills update` (`-g` for global installs, `-p` for project).
   If the sandbox refuses to run these, print the exact commands for the user instead of failing.
4. **Reconcile.** What an update changes only lands after this:
   - Everywhere: start a new session so the updated skills load.
   - Codex, when hooks changed: review and re-trust with `/hooks`. Codex skips changed hooks until re-trusted.
5. **Report** the version before and after, which channel(s) were updated, and exactly what remains for the user: new session, `/hooks`, or nothing.

## FYI

- Both install channels can coexist on one machine. When they do, update and report both.
- An update takes effect only in a new session. Until then, the skills loaded in this session are the pre-update ones.
- On a plugin install the hooks come with the plugin, and a folder install has no hook-merge step, so reconciling is just the new session (and, on Codex, the `/hooks` re-trust when hooks changed).
