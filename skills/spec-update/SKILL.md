---
name: spec-update
description: Update an installed Spec-Kit and reconcile what the update touched. Use when a user asks to update spec-kit or the Speqq skills, check whether a newer version exists, or after an update is announced. Detects the install channel — plugin or plain skill folders — reports installed vs latest version, runs the update commands the harness allows (handing the user the rest), and names the post-update steps, including the /hooks re-trust on Codex when hooks changed.
---

# spec-update

Updates the kit the way it was installed. Never guess the channel or a version —
detect both, and report "unknown" over inventing either.

## Steps

1. **Detect the install channel.**
   - Plugin: `claude plugin list` shows `spec-kit@speqq` (Claude Code);
     `codex plugin list --json` shows it (Codex).
   - Folders: `spec-*` skill directories under `~/.claude/skills/` or
     `.claude/skills/` (Claude Code), `~/.agents/skills/` or `.agents/skills/`
     (Codex) with no plugin entry.
   Both can coexist; if they do, say so and update both.

2. **Check versions.** Installed: the version in the plugin listing, or
   `skills/spec-setup/VERSION` inside a folder install (older folder installs
   predate the marker — report that plainly). Latest: refresh the marketplace
   first — `claude plugin marketplace update speqq` / `codex plugin marketplace
   upgrade` — then read the listing. If installed already equals latest, report
   that and stop.

3. **Update.**
   - Claude Code plugin: `claude plugin update spec-kit@speqq`
   - Codex plugin: `codex plugin add spec-kit@speqq` — re-adding installs the
     refreshed version. If the sandbox refuses to run these, print the exact
     commands for the user instead of failing.
   - Folders: `npx skills update` (`-g` for global installs, `-p` for project).

4. **Reconcile.** What an update changes only lands after this:
   - Everywhere: start a new session so the updated skills load.
   - Codex, when hooks changed: review and re-trust with `/hooks` — Codex
     skips changed hooks until re-trusted.
   - Folder installs with the session hooks wired: say "set up Speqq" so
     spec-setup re-merges the hook entries from the updated fragments.

5. **Report** the version before and after, which channel(s) were updated, and
   exactly what remains for the user — new session, `/hooks`, or nothing.
