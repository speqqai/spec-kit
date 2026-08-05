---
name: spec-setup
description: >-
  Connect a machine to Speqq and wire up the session-start hooks. Checks
  whether the Speqq MCP tools are reachable, walks the user through creating
  a token and registering the MCP server, creates the ~/.speqq/credentials
  skeleton the hooks read — the user pastes the token in themselves; the
  agent never sees it — and merges the SessionStart hook entries into the
  harness config. Use when a user wants to connect Speqq, set up the MCP
  server, install or repair the session hooks, or when another skill's
  preflight found Speqq unreachable. Re-running refreshes; it never
  duplicates.
---

# spec-setup

Gets a machine from nothing to connected: the Speqq MCP server registered with
the harness, a credentials file the hooks can read, and the session-start hooks
merged and verified. Each part is checked before it is touched, so running this
on an already-connected machine changes nothing.

One rule above everything here: **the token is the user's.** The agent never
asks for it, never reads it, never echoes it, and never runs a command that
contains it. Every step below is written so the token travels only between the
Speqq settings page and the places the user pastes it — by their hands, not
yours.

## Preflight

Establish what already works before changing anything.

1. **Are the Speqq MCP tools loaded?** Call `list_workspaces`. If it answers,
   the harness connection is done — skip the walkthrough and go straight to
   the hook install.
2. **Does the credentials file exist?** `ls -la ~/.speqq/credentials` — check
   existence and permissions only. **Never `cat` this file**; it holds the
   token. If it exists but is group- or world-readable, run
   `chmod 600 ~/.speqq/credentials` and say so.
3. **Are the hooks merged?** Look for a `SessionStart` entry pointing at
   `spec-setup/hooks/session-start.sh` in `.claude/settings.json` (or
   `~/.codex/hooks.json` for Codex).

Report the three answers, then do only what is missing.

## Connect Speqq

The harness connection and the credentials file are two copies of the same
thing: the harness registration gives the *agent* its MCP tools; the
credentials file gives the *hooks* theirs, because a SessionStart hook runs
outside the harness's MCP client. Set up both.

1. **The user creates a token.** In Speqq: **Settings → MCP Tokens**, create a
   token, copy it. It is shown once. It stays in their clipboard — do not ask
   them to paste it into the conversation.
2. **The user registers the MCP server.** Give them the command with a
   placeholder and have them run it in their own terminal, substituting the
   token themselves:

   ```bash
   claude mcp add --transport http speqq https://speqq.com/mcp \
     --header "Authorization: Bearer <your-token>"
   ```

   For Codex CLI, Cursor, or Gemini CLI, point them at the per-harness entries
   in `docs/connect-speqq.md`. The command contains the token, which is exactly
   why the agent gives instructions instead of running it.
3. **Create the credentials skeleton.** This part the agent does — it contains
   no secret:

   ```bash
   mkdir -p ~/.speqq && chmod 700 ~/.speqq
   [ -f ~/.speqq/credentials ] || printf '%s\n' \
     'SPEQQ_MCP_URL=https://speqq.com/mcp' \
     'SPEQQ_MCP_TOKEN=' \
     '# SPEQQ_WORKSPACE_ID=<only needed when the token sees several workspaces>' \
     > ~/.speqq/credentials
   chmod 600 ~/.speqq/credentials
   ```

   Then the user opens `~/.speqq/credentials` in their own editor and pastes
   the token after `SPEQQ_MCP_TOKEN=`. Never create the file with a real token
   in it, and never verify their paste by reading the file — verify by running
   the hook (below), whose output proves the credential works without showing
   it.
4. **Restart the session** so the MCP tools load, then confirm with
   `list_workspaces`.

## Install the hooks

The hook files already sit inside this skill's own `hooks/` directory —
`skills add` put them on disk, so there is nothing to download. What remains is
one merge, one chmod, and one verification.

1. **Make the dispatcher executable:**

   ```bash
   chmod +x .claude/skills/spec-setup/hooks/session-start.sh
   ```

2. **Merge the settings fragment.** For Claude Code, read
   `hooks/claude-code.settings.json` and merge its two `SessionStart` entries
   (matchers `startup|resume|clear` and `compact`) into the project's
   `.claude/settings.json` — into an existing `hooks.SessionStart` array if one
   exists, creating the file and keys if not. Never replace hooks that are
   already there. For Codex CLI (0.124.0 or newer), merge `hooks/codex.hooks.json`
   into `~/.codex/hooks.json` the same way; Codex trust-gates new hooks, so tell
   the user to run `/hooks` there and trust the entry.

   The fragment's `command` assumes the skill lives at
   `.claude/skills/spec-setup/`. If this harness installed it elsewhere (Codex
   uses `.agents/skills/`, a global install uses the home directory), fix the
   path during the merge so it points at where `session-start.sh` actually is.
3. **Verify by running exactly what the harness will run:**

   ```bash
   printf '{"session_id":"install-check","source":"startup"}' \
     | sh .claude/skills/spec-setup/hooks/session-start.sh
   ```

   Read the output and report what it means. Connected: a
   `Speqq connected - workspace <name> (<id>) - session install-` line followed
   by the workspace context. No credentials yet: a setup-guidance block, which
   means the walkthrough above is unfinished. Anything else: stdout stays empty
   and one stderr line names the cause — an unreachable server, a rejected
   token, an ambiguous workspace. The script always exits 0; judge it by its
   output, never its exit code.

4. **Tell the user to restart the session** (or run `/hooks` to confirm the
   entry was picked up). The next session opens with the orientation injected.

## Re-run safety

Running spec-setup again is a refresh, not a reinstall. The preflight decides
what is missing; everything present is left alone. Specifically:

- An existing `~/.speqq/credentials` is never overwritten and never read —
  only its permissions are checked.
- Merging checks for an existing `SessionStart` entry whose command points at
  `session-start.sh` and updates it in place. It never appends a duplicate —
  two entries would run the hook twice per session.
- The verification run is always safe to repeat: the hook writes nothing
  outside a temp directory it removes on exit.

## Worth being careful about

- **Never handle the token.** Not in a command you run, not in a file you
  write, not in chat, not in a diagnostic you quote. If the user pastes it
  into the conversation unprompted, tell them to revoke it in Settings → MCP
  Tokens and create a fresh one — a token that has been in a transcript is
  burned.
- **Never read `~/.speqq/credentials`.** `ls -la` tells you everything this
  skill needs to know about it.
- **The hooks are optional.** Every `spec-*` skill orients itself with its own
  MCP calls; the hooks make that automatic at session start. A user who wants
  only the connection can stop after the walkthrough.
- **Hooks run on Claude Code and Codex CLI only today.** Cursor and Gemini CLI
  session hooks require a single JSON object on stdout, and these hooks write
  plain text. Say so rather than wiring up something that cannot fire; the
  skills themselves work on all four harnesses.
