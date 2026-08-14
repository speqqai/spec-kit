---
name: spec-setup
description: >-
  Connect a machine to Speqq and wire up the session hooks. Checks whether
  the Speqq MCP tools are reachable, registers the MCP server for the
  harness in use — Claude Code or Codex CLI, OAuth first so no token is
  needed — and merges the full hook pack — SessionStart, PostToolUse,
  PreCompact, SessionEnd — into the harness config. The optional hook token
  (rich-mode injection and the loss-point memory writes) gets a
  ~/.speqq/credentials skeleton the user pastes into themselves; the agent
  never sees it. Use when a user wants to connect Speqq, set up the MCP
  server, install or repair the session hooks, or when another skill's
  preflight found Speqq unreachable. Re-running refreshes; it never
  duplicates.
---

# spec-setup

Gets a machine from nothing to connected: the Speqq MCP server registered with
the harness, a credentials file the hooks can read, and the session hooks
merged and verified. Each part is checked before it is touched, so running this
on an already-connected machine changes nothing.

This skill is harness-aware: it wires the harness it is running in, and the
steps below name both forms where they differ. A user who wants another
harness connected too runs this skill there.

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
2. **Does the credentials file exist?** (Optional — only rich mode and the
   loss-point memory writes need it; absent is the normal instruction-mode
   default.) `ls -la ~/.speqq/credentials` — check existence and permissions
   only. **Never `cat` this file**; it holds the token. If it exists but is
   group- or world-readable, run `chmod 600 ~/.speqq/credentials` and say so.
3. **Are the hooks merged — all four events?** Look for entries pointing at
   `spec-setup/hooks/` scripts under `SessionStart`, `PostToolUse`,
   `PreCompact`, and `SessionEnd` in the harness config: `.claude/settings.json`
   for Claude Code; `~/.codex/hooks.json` for Codex CLI (a trusted project may
   carry `.codex/hooks.json`, or a `[hooks]` table in `config.toml`, instead).
   Some events present but not all means an install from an older pack — the
   merge below completes it.

Report the three answers, then do only what is missing.

## Connect Speqq

The harness connection and the credentials file are two copies of the same
thing: the harness registration gives the *agent* its MCP tools; the
credentials file gives the *hooks* theirs, because a SessionStart hook runs
outside the harness's MCP client. Set up both.

1. **Register the MCP server — OAuth first, no token involved.** For Claude
   Code:

   ```bash
   claude mcp add --transport http speqq https://speqq.com/mcp
   ```

   then the user runs `/mcp` in a session and authenticates — their browser
   opens a Speqq login. For Codex CLI, register the server:

   ```bash
   codex mcp add speqq --url https://speqq.com/mcp
   ```

   then the user runs `codex mcp login speqq`. Confirm with
   `claude mcp list` / `codex mcp list`.

   If a harness cannot OAuth (Cursor and Gemini CLI vary; service accounts
   prefer it), fall back to a bearer token the USER substitutes themselves:
   Claude Code takes `--header "Authorization: Bearer <token>"` on the add
   command; Codex takes `bearer_token_env_var = "SPEQQ_MCP_TOKEN"` in the
   entry (never a literal token key) with the env var exported in their
   shell profile. Tokens come from **Settings → MCP Tokens** in Speqq,
   shown once, and stay in the user's hands — the command or file contains
   the token, which is exactly why the agent gives instructions instead of
   running them.
2. **(Optional) the hook token — only for rich mode and the loss-point
   memory writes.** Skip unless the user wants those; the hooks work
   without any credentials. When opting in, the agent creates the skeleton —
   it contains no secret:

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
3. **Restart the session** so the MCP tools load, then confirm with
   `list_workspaces`.

## Install the hooks

The hook files already sit inside this skill's own `hooks/` directory —
`skills add` put them on disk, so there is nothing to download. What remains is
one chmod, one merge, and one verification. Two facts decide the details, so
resolve them first:

- **The skill's real path.** Find where THIS skill folder actually lives.
  Project installs sit at `.claude/skills/spec-setup/` (Claude Code) or
  `.agents/skills/spec-setup/` (Codex CLI); global installs sit under the
  home directory (`~/.claude/skills/spec-setup/`,
  `~/.agents/skills/spec-setup/`). The fragments ship with the
  project-install path in every `command` — for any other location, rewrite
  each command's path during the merge to the absolute path where
  `session-start.sh` actually is. A command pointing at a path that only
  resolves from one directory is the pack's oldest install bug; fix it here,
  not after a silent session.
- **The harness config file.** `.claude/settings.json` for Claude Code;
  `~/.codex/hooks.json` for Codex CLI (inside a trusted project,
  `.codex/hooks.json` works and keeps the fragment's relative paths valid).

1. **Make the three executables executable** — the dispatcher and both
   stand-alone hooks:

   ```bash
   chmod +x <skill-path>/hooks/session-start.sh \
     <skill-path>/hooks/spec-memory.sh \
     <skill-path>/hooks/spec-context-watch.sh
   ```

2. **Merge the settings fragment — all of it.** The pack wires four events;
   merging less ships a machine that quietly loses its memory writes or its
   checkpoint ladder:

   | Event | Matcher | Runs |
   | --- | --- | --- |
   | `SessionStart` | `startup\|resume\|clear` | `session-start.sh` |
   | `SessionStart` | `compact` | `session-start.sh` |
   | `PostToolUse` | `.*` | `spec-context-watch.sh` |
   | `PreCompact` | `manual\|auto` | `spec-memory.sh` |
   | `SessionEnd` | (all reasons) | `spec-memory.sh` |

   For Claude Code, read `hooks/claude-code.settings.json` and merge every
   entry into the harness config — into existing event arrays where they
   exist, creating the file and keys if not. Never replace hooks that are
   already there. For Codex CLI, merge `hooks/codex.hooks.json` into
   `~/.codex/hooks.json` the same way, keeping each entry's `statusMessage`,
   `timeout`, and `additionalContextLimit` fields — they fit Codex's limits
   (SessionEnd hooks get 3 seconds at most, and the SessionStart entries
   disable the default 2,500-character context cap that would truncate the
   injection). Fix each merged `command` to the real skill path resolved
   above.

   Codex trust-gates hooks: tell the user to run `/hooks` there and trust
   each entry — and that the same review reappears after any future change
   to an entry, because trust is keyed to the entry's content. That is Codex
   behavior, not a fault. Version floors, honestly: the pack is tested on
   Codex 0.147.0; earlier builds lose capabilities roughly bottom-up —
   SessionEnd needs about 0.145, PreCompact and the PostToolUse ladder about
   0.129, SessionStart about 0.114 (its `compact` source about 0.133). Name
   what a given build loses rather than refusing outright.

3. **Verify by running exactly what the harness will run:**

   ```bash
   printf '{"session_id":"install-check","source":"startup"}' \
     | sh <skill-path>/hooks/session-start.sh
   ```

   Read the output and report what it means. With a hook token: a
   `Speqq connected - workspace <name> (<id>) - session install-` line followed
   by the workspace context. Without one: the orient instruction — that is
   instruction mode, the default, and it means the hooks work. Anything else:
   stdout stays empty and one stderr line names the cause — an unreachable
   server, a rejected token, an ambiguous workspace. The script always exits
   0; judge it by its output, never its exit code.

4. **Tell the user to restart the session** (or run `/hooks` — both harnesses
   have it — to confirm the entries were picked up). The next session opens
   with the orientation injected.

## Re-run safety

Running spec-setup again is a refresh, not a reinstall. The preflight decides
what is missing; everything present is left alone. Specifically:

- An existing `~/.speqq/credentials` is never overwritten and never read —
  only its permissions are checked.
- Merging matches existing entries by the script each `command` points at —
  `session-start.sh`, `spec-context-watch.sh`, `spec-memory.sh` — and updates
  them in place, across all four events. It never appends a duplicate — two
  entries would run a hook twice per firing. An install from an older pack
  that carried only `SessionStart` gains the missing events; nothing else
  changes.
- On Codex, an updated entry goes back through the `/hooks` review — trust is
  keyed to the entry's content. Say so up front; it is one keystroke, not a
  problem to solve.
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
