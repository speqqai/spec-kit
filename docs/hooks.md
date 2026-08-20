# Session hooks

Spec-Kit ships an optional hook pack as part of the spec-kit plugin. The pack
is four single-duty, tokenless, capacity-driven `PostToolUse` hooks plus a
shared `lib.sh`. No hook opens an MCP connection, resolves credentials, or
makes a network call. Each hook measures how full the local context window is,
reading the figure from the session transcript, and at its rung prints one
short instruction to stdout for the agent to act on over its own Speqq MCP
connection.

There is no `SessionStart`, no `PreCompact`, and no `SessionEnd` hook, and
there is no hook token. Everything runs on `PostToolUse`, and the shell only
measures and speaks: the agent does the reading and the saving with its own
MCP tools.

The hooks are optional. Every `spec-*` skill makes the same calls itself when
asked. The hooks make orientation and checkpointing automatic, which matters
most in the sessions where nobody thinks to ask for it.

## The four hooks

Each hook has one duty and fires at one point in the fill of the context
window.

1. **`read-product-context.sh` (orient).** Fires once per window while the
   window is near empty (measured fill below `SPEQQ_CONTEXT_ORIENT_PCT`,
   default 10). Injects one instruction: orient by reading the product brief.
   Call `spec_orient`, then `spec_read` the `product_file` pointer it returns
   (PRODUCT.md). It reads the product node only, and never mentions the open
   or active work.

2. **`read-memory.sh` (recall).** Fires once per window at the same near-empty
   rung. Injects one instruction: resolve the active spec from the current git
   branch with `spec_orient`, then `spec_memory_read` it to catch up on the
   story of the work so far. The hook reads the branch locally and names it in
   the instruction when it can.

3. **`append-memory.sh` (checkpoint ladder).** The checkpoint ladder, minus
   the near-empty rung the two read hooks own. Fires once each at the rungs in
   `SPEQQ_CONTEXT_NUDGE_PCT` (default `25,50,75,95`) as the window fills.
   Injects one instruction: find the queue item whose branch matches, take its
   linked spec, and append 2 to 4 sentences on where the work stands with
   `spec_memory_append`. The early rungs say "checkpoint." The top rung (95),
   sitting just under auto-compaction, says "save now, while you still have
   full context." The memory log ends up reading top to bottom as the story of
   the session, written by the agent itself.

4. **`prefer-knowledge-graph.sh` (knowledge-graph tip).** Fires once per
   session on `PostToolUse` after a filesystem search: a `Grep` or `Glob` tool
   call, or a `Bash` command that runs `grep`, `rg`, `ag`, or `find`. Injects one
   recommendation: prefer `semantic_search_nodes`, `search_nodes`, or
   `get_context` over filesystem grep and glob for understanding the codebase,
   with grep and glob as the fallback when Speqq does not answer. Disable it
   with `SPEQQ_READ_FIRST=0`.

## What fires them

All four hooks run on `PostToolUse`. Because nothing re-arms them at the start
of a session, the pack detects a fresh window by capacity instead (see below),
so the read hooks re-fire and the ladder re-climbs after every compaction.

The three capacity hooks (`read-product-context.sh`, `read-memory.sh`,
`append-memory.sh`) run after every tool call and share the one measurement in
`lib.sh`. The read hooks fire once each while the window is near empty. The
ladder fires once at each filling rung. `prefer-knowledge-graph.sh` runs after
a filesystem-search call (`Grep`, `Glob`, or a `Bash` `grep`/`find`) and fires
once per session.

**Claude Code** wires this in `claude.plugin.hooks.json` as two `PostToolUse`
entries: a `.*` matcher that runs the three capacity hooks (10-second harness
timeout each), and a `Grep|Glob|Bash` matcher that runs the knowledge-graph tip
(5-second timeout). **Codex CLI** takes the same shape in
`codex.plugin.hooks.json`, adding a `statusMessage` per hook, loaded
automatically with the plugin. The pack is tested on Codex 0.147.0. Codex
trust-gates plugin hooks: review and enable each entry with `/hooks` in the
TUI, and expect the same review after any change to an entry, because trust is
keyed to the entry's content.

## How the hooks measure context

The measurement lives once in `lib.sh` and is shared by the three capacity
hooks. It is one Python pass over the tail of the session transcript that reads
the last usage-bearing record. Two transcript shapes are recognized, each
self-identifying so no harness flag decides the parse:

- **Claude Code JSONL.** The assistant record carries `message.usage`. The
  fill is `input_tokens` plus `cache_creation_input_tokens` plus
  `cache_read_input_tokens`.
- **Codex rollouts.** An `event_msg` record with `payload.type` of
  `token_count` carries `info.last_token_usage.input_tokens` (the last
  request's prompt size) and `info.model_context_window` (the window itself).
  These records land at each turn's end, so the ladder reads from the second
  turn of a window on.

The denominator is `SPEQQ_CONTEXT_WINDOW` when set, else the window the
transcript names (Codex does, Claude does not), else 200000. A Claude
transcript on a larger-window model can measure a fill above 100 percent of
that default. Rather than guess a bigger window, the ladder parks itself for
the window, prints one stderr line naming `SPEQQ_CONTEXT_WINDOW` as the fix,
and stops re-firing.

**Per-window rung flags.** Each hook records the rung it has fired in one flag
file per session, in the state dir (`SPEQQ_HOOK_STATE_DIR`, else the system
temp dir). The read hooks fire once. The ladder records the highest rung fired
so each rung fires at most once, and a jump past two rungs nudges only for the
highest.

**Capacity-driven reset.** With no start-of-session hook to re-arm the ladder,
capacity does it. `lib.sh` persists the last-seen fill per session id, and when
the measured fill drops more than `SPEQQ_CONTEXT_RESET_DROP` points (default
20) below the last-seen fill, a compaction or a fresh session reusing an id,
it clears the per-window flags. The read hooks then fire again and the ladder
re-climbs. This replaces the old session-start-driven reset.

**Self-timeout.** Each measurement bounds itself with a `SIGALRM` alarm
(`SPEQQ_HOOK_TIMEOUT_SECONDS`, default 5), so a pathological transcript can
never hang a tool call.

`lib.sh` requires `python3` on `PATH`. It is sourced by the three capacity
hooks and never executed. `prefer-knowledge-graph.sh` does not source it: it
runs its own small Python check and keeps its own once-per-session flag in the
temp dir.

## The invariants

Every path through these hooks holds four rules. They are what make a hook safe
to run around every tool call.

1. **It never blocks a tool call.** Every path exits 0. A missing transcript,
   an unparseable record, a timed-out measurement: the tool call proceeds, just
   without the injected instruction.
2. **Stdout is sacred.** Only the intentional context-injection JSON goes to
   stdout, and only when a rung fires. A hook that does not fire prints
   nothing.
3. **Stderr is diagnostics.** A real runtime failure prints exactly one line to
   stderr naming the cause, and still exits 0.
4. **Tokenless.** No network, no credentials, no MCP, no curl. The hooks only
   measure the local transcript and print instructions for the agent to act on
   over its own MCP connection.

## Environment

Every variable is optional. The defaults are the tested configuration.

| Key | Default | Meaning |
| --- | --- | --- |
| `SPEQQ_CONTEXT_ORIENT_PCT` | `10` | Near-empty rung. Below this fill, the two read hooks fire once each. |
| `SPEQQ_CONTEXT_NUDGE_PCT` | `25,50,75,95` | The ladder rungs, a comma list. Each fires once per window. |
| `SPEQQ_CONTEXT_RESET_DROP` | `20` | Fill drop, in points below the last-seen fill, that counts as a new window and re-arms the flags. |
| `SPEQQ_CONTEXT_WINDOW` | (unset) | Override the denominator, in tokens. Set it when a Claude model's real window is not 200000. |
| `SPEQQ_HOOK_STATE_DIR` | system temp dir | Where the per-window flag files live. |
| `SPEQQ_HOOK_TIMEOUT_SECONDS` | `5` | Self-timeout for each measurement. |
| `SPEQQ_HOOK_AGENT` | `claude-code` | Attribution name written with each memory append. The Codex manifest sets it to `codex`. |
| `SPEQQ_WORKSPACE_ID` | (unset) | Optional, non-secret. Sharpens the queue-lookup line in the checkpoint instruction. |
| `SPEQQ_READ_FIRST` | `1` | Set to `0` to disable the knowledge-graph tip. |

There is no token and no credentials file. The old rich-mode surface is gone:
`SPEQQ_MCP_URL`, `SPEQQ_MCP_TOKEN`, and `~/.speqq/credentials` are removed and
read nowhere. The hooks never authenticate, so there is nothing to configure to
make them run.

## What is in the pack

Everything lives in the pack's own directory, `hooks/`:

| File | Role |
| --- | --- |
| `read-product-context.sh` | Orient. Near-empty rung, once per window. Injects the instruction to read the product brief. |
| `read-memory.sh` | Recall. Near-empty rung, once per window. Injects the instruction to read the active spec's memory. |
| `append-memory.sh` | The checkpoint ladder. Fires at each filling rung, once each per window. Injects the instruction to append a progress note to spec memory. |
| `prefer-knowledge-graph.sh` | The knowledge-graph tip. Once per session after `Grep`/`Glob`. Injects the recommendation to prefer the Speqq knowledge graph over filesystem search. |
| `lib.sh` | Shared plumbing: the context-fill measurement, the per-window rung flags, the capacity-driven reset, and the self-timeout. Sourced by the three capacity hooks, never by `prefer-knowledge-graph.sh`, and never executed. |
| `claude.plugin.hooks.json` | The Claude Code plugin hook manifest: the two `PostToolUse` entries, loaded automatically with the plugin. |
| `codex.plugin.hooks.json` | The same manifest shape for the Codex plugin. |

Requires `python3` on `PATH`, and `git` to read the branch (no git, no branch,
and the instruction names the current branch generically instead).

## Install and verify

The hooks ship inside the spec-kit plugin and load automatically once the
plugin is installed. There is no `settings.json` to merge and nothing to make
executable by hand. See the Get started guide for installing the plugin.

To verify a hook by hand, pipe a mock `PostToolUse` payload to it from the
plugin's own directory. Point `transcript_path` at any real transcript file so
the measurement has something to read:

```bash
printf '{"session_id":"t","transcript_path":"<a transcript>","tool_name":"Read"}' \
  | sh hooks/read-memory.sh
```

When the transcript's fill is below the near-empty rung, you get the injection
JSON on stdout. When it is not, stdout stays empty, which is the hook working
correctly. Anything broken prints one stderr line naming the cause. The exit
code is always 0, so judge the hook by its output, not its status.

## Remove

Uninstall the spec-kit plugin (or disable its hooks) and restart the harness.
The only thing left behind is the small per-window flag files in the state dir,
which are harmless and reused by session id. The skills keep working without
the hooks.

## Harness support

The hooks run on **Claude Code** and **Codex CLI** (tested on 0.147.0) today.
Cursor and Gemini CLI are not supported: the hooks are Claude Code and Codex
only. The skills themselves run on all four harnesses regardless.
