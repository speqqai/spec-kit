---
name: speqq-mcp-connect
description: Check the Speqq MCP connection and repair it - register the server when it is missing, walk the user through re-authentication when the sign-in has expired, and say exactly when a new session is needed. Use when Speqq tools are missing or erroring, on auth or 401 or unauthorized errors from Speqq calls, or when a user says the connection is lost, or asks to connect, reconnect, re-authenticate, sign in again, or install or set up the Speqq MCP server. Connection only - hooks and the rest of machine setup stay with spec-setup.
---

# speqq-mcp-connect

A ladder, run top down; stop at the first rung that fixes it. Report every rung
you ran as a check - what was tested, what answered - so the user sees exactly
where the connection stands. Never ask for a token or password in chat; the
browser sign-in is the whole flow.

## 1. Try the tools

Call `list_workspaces`. If it returns workspaces: connected and authenticated -
say so and stop. Otherwise the failure tells you which rung is next:

- The Speqq tools are not in this session at all → rung 2.
- The tools exist but the call fails with an auth-shaped error (401,
  unauthorized, invalid or expired token) → rung 3.
- Any other error: report it verbatim - that is a different problem, not
  the connection ladder.

## 2. Not registered → register

Check what the harness has: `claude mcp list` (Claude Code) or
`codex mcp list` (Codex), looking for `speqq` or the plugin-provided
`plugin:spec-kit:speqq`.

- **Listed already?** The session just predates it - skip to rung 4.
- **Spec-Kit plugin installed** (`claude plugin list` / `codex plugin list`)?
  The server ships with it; skip to rung 4, then rung 3 in the new session.
- **Truly missing** - register it:
  - Claude Code: `claude mcp add --scope user --transport http speqq https://speqq.com/mcp`
  - Codex: add to `~/.codex/config.toml` (edit it if the harness lets you,
    otherwise print it for the user):

    ```toml
    [mcp_servers.speqq]
    url = "https://speqq.com/mcp"
    auth = "oauth"
    ```

  Then rung 3 for the first sign-in.

## 3. Registered but not signed in → authenticate

- **Claude Code**: the agent cannot do this part - tell the user: run `/mcp`,
  select the `speqq` server, choose Authenticate, and finish the browser login.
- **Codex**: run `codex mcp login speqq` - it opens the browser. If the
  sandbox refuses to run it, print the command for the user. If Codex answers
  that no such server exists, the server is plugin-owned: tell the user to
  authenticate it from the harness's MCP or plugin UI.

If sign-in keeps expiring and this ladder is being re-run often, say so in the
report and tell the user to report it to Speqq - repeated expiry is a
server-side refresh problem, not something the user is doing wrong.

## 4. Restart so it lands

MCP servers and their auth load at session start. After registering or signing
in, tell the user to start a new session, then re-run rung 1 there. On Claude
Code a fresh `/mcp` authentication sometimes takes effect live - if the tools
answer without a restart, done; if not, the new session is the fix, not a
deeper failure.

## 5. Report

One line per rung that ran: check passed, or what was done about it, and the
single action left for the user - new session, browser sign-in, or nothing.
