# Session hooks

Spec-Kit ships an optional hook pack inside the `spec-setup` skill. When a
coding session starts, the harness runs one script that opens a single
connection to the Speqq MCP server and injects three things as session context —
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

3. **Active work** — the recall half of the memory system (see
   [spec-active-work](#spec-active-work--the-recall-step) below): the open
   queue items, the active spec resolved from the current git branch, the tail
   of that spec's MEMORY.md verbatim, and an identity coda naming which
   session THIS is.

The hooks are optional. Every `spec-*` skill makes the same calls itself when
asked; the hooks make orientation automatic, which matters most in the sessions
where nobody thinks to ask for it.

## What fires them

Both harnesses fire the same script on session start; the script reads the
hook's stdin JSON (`session_id`, `source`) to tell the cases apart.

| Session event | Connection status | Workspace context | Active work | Summary instruction |
| --- | --- | --- | --- | --- |
| New session (`startup`) | printed | printed | printed | — |
| Resumed session (`resume`) | printed | printed | printed | — |
| Cleared session (`clear`) | printed | printed | printed | — |
| After compaction (`compact`) | skipped | printed | printed | printed |

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
15-second harness timeout. **Codex CLI** takes the same shape in
`~/.codex/hooks.json`. Codex floors differ per event: SessionStart needs
0.114.0 (its `compact` source 0.133.0), PreCompact and the PostToolUse
ladder 0.129.0, SessionEnd 0.145.0 — the full pack wants 0.145.0 or newer; Codex
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

## spec-active-work — the recall step

Writing memory is only half a memory system; `spec-active-work.sh` is the
half that reads it back. It runs as a session-start step on **every** source
— `startup`, `resume`, `clear`, and `compact` — right after the workspace
context, and injects three things:

1. **Open work** — up to 8 queue items that are in progress or todo
   (in-progress first), each as `title [status] - branch` when a branch is
   linked. An empty queue is one honest line, and past 8 the note names
   `queue_read` as the call that lists the rest.

2. **The active spec's memory tail** — the queue item whose branch field
   exactly matches the current git branch names the active spec through its
   linked document; `spec_memory_read` returns the last 12 MEMORY.md
   snippets and the step prints them verbatim, newest last. This is the
   direct payoff of every line `spec-memory.sh` and the checkpoint ladder
   wrote: the next session opens already knowing what happened. No current
   branch, no queue item claiming it, no linked spec — one honest line
   naming which, and the open-work listing still prints.

3. **The identity coda** — whenever a session id is known:

   ```
   You are session a1b2c3d4 (claude-code). Memory lines carry the session that wrote them - lines from other sessions are earlier work; read them as a handoff, not your own memory.
   ```

   Memory lines are attributed (`agent · session8 ·`), so without this line
   an agent has no way to tell its own earlier snippets from another
   session's. With it, the log reads correctly as a handoff.

The step holds the same invariants as its siblings, plus one of its own:
each section is buffered and printed whole or not at all, so a failure
mid-run (say `spec_memory_read` timing out) keeps every section already
printed, adds one stderr line naming the cause, and never blocks the
session. Its calls ride the same open MCP connection and the same shared
deadline as every other step.

## spec-context-watch — the checkpoint ladder

The one thing a compaction hook can never do is put text in front of the
model — so the pack gets ahead of compaction instead. `spec-context-watch.sh`
runs on `PostToolUse` (every tool call), reads the session transcript's last
assistant record for its `message.usage` token counts, and computes how full
the context window is. As the window fills it nudges the live agent at three
rungs — 30%, 60%, and 85% by default (`SPEQQ_CONTEXT_NUDGE_PCT` takes a
comma list) — each time injecting one instruction the model reads on its
next request: record where the work stands in spec memory — resolve the
active spec from the branch, append 2-4 sentences of real state, then
continue. The early rungs say "checkpoint"; the final rung, sitting under
the auto-compaction threshold, says "save now, while you still have full
context."

The memory log ends up reading as a chronological story of the session,
written by the agent itself — and the pre-compaction summary happens the
only way the harness allows: the live agent, warned in time, writes it.
Each rung fires once per window (a session-keyed flag records the highest
rung fired); the post-compaction firing of the session-start dispatcher
clears the flag, so the next window climbs the ladder again. Between rungs
the hook is silent and costs a few milliseconds; no network, no
credentials — it only measures and speaks, and the agent does the saving
with its own MCP tools.

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
| `spec-active-work.sh` | The recall step — open work, the active spec's memory tail, and the session identity coda |
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

The hooks run on **Claude Code** and **Codex CLI** (SessionStart from
0.114.0; the full pack from 0.145.0) today. Cursor
and Gemini CLI both have session-start hook systems, but each requires a
single JSON object on stdout — Gemini treats plain text as a parse failure —
and these hooks write plain text. Until that is wired, the hooks are not
installed there. The skills themselves run on all four harnesses regardless.
