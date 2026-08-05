# Session hooks

Spec-Kit ships an optional hook pack inside the `spec-setup` skill. When a
coding session starts, the harness runs one script that opens a single
connection to the Speqq MCP server and injects two things as session context —
before you type anything:

1. **Connection status** — one line confirming the session is wired up:

   ```
   Speqq connected - workspace Speqq (9f3c...) - session a1b2c3d4
   ```

   The trailing token is the first eight characters of the harness session id.
   If no credentials are found anywhere, this step instead prints a short setup
   block that tells the agent to walk you through connecting — so a fresh
   machine's first session starts with the fix, not a silent gap.

2. **Workspace context** — the workspace's PRODUCT.md, the product brief:
   what the product is, who it is for, what must never break. The agent opens
   the session already knowing what it is building, without being asked. A
   workspace that has not written one gets a single line naming the gap, so
   the agent can offer to create it.

The hooks are optional. Every `spec-*` skill makes the same calls itself when
asked; the hooks make orientation automatic, which matters most in the sessions
where nobody thinks to ask for it.

## What fires them

Both harnesses fire the same script on session start; the script reads the
hook's stdin JSON (`session_id`, `source`) to tell the cases apart.

| Session event | Connection status | Workspace context | Summary instruction |
| --- | --- | --- | --- |
| New session (`startup`) | printed | printed | — |
| Resumed session (`resume`) | printed | printed | — |
| Cleared session (`clear`) | printed | printed | — |
| After compaction (`compact`) | skipped | printed | printed |

The compact row is deliberate: a compaction squeezes the context window
mid-session, so the orientation is re-injected — but the connection does not
need re-announcing. And because the agent is the only writer that can say
what the work *means*, the compact firing also injects a direct instruction:
resolve the active spec from the current branch and append a 2-4 sentence
summary — what it was doing, the current state, the next step — with
`spec_memory_append`, then continue. The division of labor is strict: shell
records facts, the agent records meaning, and the injection is the bridge
that makes the second one happen without anyone asking.

**Claude Code** wires this as two `hooks.SessionStart` entries (matchers
`startup|resume|clear` and `compact`) running
`$CLAUDE_PROJECT_DIR/.claude/skills/spec-setup/hooks/session-start.sh` with a
15-second harness timeout. **Codex CLI** (0.124.0 or newer — earlier builds
have no hooks engine) takes the same shape in `~/.codex/hooks.json`; Codex
trust-gates newly added hooks, so review and enable the entry with `/hooks` in
the TUI. On some Codex builds a bare `codex` that silently restores the
previous thread skips `SessionStart` entirely
([openai/codex#24228](https://github.com/openai/codex/issues/24228)); starting
a genuinely new session is the workaround.

## spec-memory

The pack also ships one write hook, `spec-memory.sh`. Where the session-start
script reads Speqq into the session, this one writes the session back — at the
two moments its context is about to be lost:

| Event | When it fires | The recorded line ends up saying |
| --- | --- | --- |
| `PreCompact` (`manual\|auto`) | right before the context window is compacted | `compacting on <branch> - dirty: <n> files (<up to 3 names>)` |
| `SessionEnd` | when the session ends | `session ended on <branch> - dirty: <n> files` |

The hook appends that one line to the MEMORY.md of the **active spec** — the
workspace queue item whose branch field exactly matches the current git
branch, through its linked spec document. The server stamps the time and
composes the full line; with the attribution the wiring supplies it reads:

```
2026-08-05 14:02  claude-code · a1b2c3d4 · compacting on feat/checkout - dirty: 3 files (a.ts, b.ts, c.md)
```

`claude-code` is the agent name the wiring passes as `SPEQQ_HOOK_AGENT`
(`codex` in the Codex wiring), and `a1b2c3d4` is the first eight characters of
the harness session id — the same short form the connection-status line
prints, so a memory line can be traced back to the session that wrote it.
Attribution travels as one unit: if either half is missing or malformed, the
hook says so on stderr and records the line unattributed rather than losing
it.

Every miss is a skip, not a failure: no credentials, no current git branch,
no queue item claiming the branch — one stderr line naming the cause, exit 0,
nothing written and nothing guessed. And unlike the session-start script this
hook injects nothing: **stdout stays empty on every path**. Recall after
compaction is the SessionStart hooks' job — the `compact` matcher re-injects
the workspace context, and the `spec-*` skills read MEMORY.md itself when
asked. The write is best-effort under the same shared deadline as everything
else: a slow server costs the memory line, never the compaction or the exit.

The wiring adds a `PreCompact` entry (matcher `manual|auto`) and a
`SessionEnd` entry to the same config files as the session-start hooks, each
running `spec-memory.sh` with `SPEQQ_HOOK_AGENT` set in the command string.
To verify by hand:

```bash
printf '{"session_id":"install-check","hook_event_name":"SessionEnd","reason":"other"}' \
  | SPEQQ_HOOK_AGENT=claude-code sh .claude/skills/spec-setup/hooks/spec-memory.sh
```

Success is silent — the line lands in the spec's MEMORY.md and nothing is
printed. Anything skipped or broken is one stderr line naming the cause;
stdout is empty either way.

## The four invariants

Every path through both scripts holds four rules. They are what make a hook
safe to run around every session:

1. **It never blocks a session.** Every failure exits 0. Missing credentials,
   an unreachable server, a rejected token — the session starts anyway, just
   without the injected context.
2. **It never fails silently.** Every failure prints exactly one line to
   stderr naming the cause. No failure is ever guessed around: no invented
   workspace, no defaulted server.
3. **It never leaks the token.** The token lands only in a `0600` curl config
   file inside a private temp directory removed on exit — never on a command
   line where `ps` would show it, never on stdout, never in a diagnostic.
4. **One shared deadline.** The whole run — every step, every request — is
   bounded by 8 seconds of wall clock against a single deadline, not a budget
   per request. `SPEQQ_HOOK_TIMEOUT_SECONDS` overrides it. Session start is
   not the place to wait.

And one discipline underneath them: stdout carries only the injected context
itself. Everything else — status, warnings, causes — goes to stderr, so the
agent's context is never polluted with plumbing.

## Credentials

The script resolves its connection in two layers; the first one that answers
wins.

| Key | Meaning |
| --- | --- |
| `SPEQQ_MCP_URL` | Full MCP endpoint, e.g. `https://speqq.com/mcp` |
| `SPEQQ_MCP_TOKEN` | Your Speqq MCP token |
| `SPEQQ_WORKSPACE_ID` | Optional — only needed when the token can see several workspaces |

1. **Environment variables** with those names, when set.
2. **`~/.speqq/credentials`** — a dotenv-style file carrying the same three
   `KEY=value` lines (`SPEQQ_CREDENTIALS_FILE` overrides the path). The script
   parses it line by line and never sources it, so the file cannot execute
   anything. Keep it `chmod 600` inside a `chmod 700` directory; if it is
   group- or world-readable the hook prints one warning naming the fix and
   continues.

Neither layer present is **not an error** — it is the fresh-machine case, and
the connection-status step answers it with setup guidance instead of a
diagnostic. The `spec-setup` skill creates the credentials file skeleton for
you; you paste the token in yourself, and the agent never sees it.

## What is in the pack

Everything lives in the skill's own directory,
`skills/spec-setup/hooks/`:

| File | Role |
| --- | --- |
| `session-start.sh` | The read hook, fired at session start — parses the hook stdin, resolves credentials, opens one MCP session, runs the steps under the shared deadline |
| `lib.sh` | Shared plumbing: credentials resolution, deadline, transport — sourced, never executed |
| `speqq-setup.sh` | The connection-status step |
| `spec-workspace-context.sh` | The workspace-context step |
| `spec-memory.sh` | The write hook — records one memory line at `PreCompact` and `SessionEnd` |
| `claude-code.settings.json` | The `SessionStart`, `PreCompact`, and `SessionEnd` entries to merge into `.claude/settings.json` |
| `codex.hooks.json` | The same shape for `~/.codex/hooks.json` |

Requires `curl` and `python3` on `PATH`, and `git` to read the branch (no git,
no branch — the context is fetched without one, honestly).

## Install and verify

The files are already on disk — `npx skills add speqqai/spec-kit` ships them
inside the skill. Wiring them up is one merge, and the easiest way is to ask
your agent to **"set up Speqq"**: the `spec-setup` skill merges the
`SessionStart` entries into your harness config, makes `session-start.sh`
executable, and verifies the result. Re-running it refreshes the entries; it
never duplicates them.

To verify by hand, run exactly what the harness runs:

```bash
printf '{"session_id":"install-check","source":"startup"}' \
  | sh .claude/skills/spec-setup/hooks/session-start.sh
```

Connected, you get the status line and the workspace context on stdout. Not
connected, you get the setup guidance. Anything broken, stdout stays empty and
one stderr line names the cause. The exit code is always 0 — judge the hook by
its output.

## Remove

Delete the merged `SessionStart`, `PreCompact`, and `SessionEnd` entries from
`.claude/settings.json` (or `~/.codex/hooks.json`) and restart the harness. Nothing else is left behind:
the hooks write no state, no cache, and no files outside a temp directory
removed on exit. The skills keep working without them.

## Harness support, honestly

The hooks run on **Claude Code** and **Codex CLI (0.124.0+)** today. Cursor
and Gemini CLI both have session-start hook systems, but each requires a
single JSON object on stdout — Gemini treats plain text as a parse failure —
and these hooks write plain text. Until that is wired, the hooks are not
installed there. The skills themselves run on all four harnesses regardless.
