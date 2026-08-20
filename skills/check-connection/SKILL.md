---
name: check-connection
description: Check the Speqq MCP connection and repair it: register the server when it's missing, walk the user through re-authentication when the sign-in has expired, and say exactly when a new session is needed. Use when Speqq tools are missing or erroring, on auth, 401, or unauthorized errors from Speqq calls, or when a user says the connection is lost, or asks to connect, reconnect, re-authenticate, sign in again, or install or set up the Speqq MCP server. Connection only; hooks and the rest of machine setup come with the Spec-Kit plugin.
---

# Check connection

A ladder, run top down: stop at the first rung that fixes it. Report every rung you ran as a check, what was tested and what answered, so the user sees exactly where the connection stands.

## Prerequisites

- You're on a supported harness: Claude Code or Codex.

## Steps

1. **Try the tools.** Call `list_workspaces`. If it returns workspaces, Speqq is connected and authenticated: say so and stop. Otherwise the failure names the next rung:
   - The Speqq tools aren't in this session at all: go to step 2.
   - The tools exist but the call fails with an auth-shaped error (401, unauthorized, invalid or expired token): go to step 3.
   - Any other error: report it verbatim. That's a different problem, not the connection ladder.
2. **Register the server if it's missing.** Check what the harness has: `claude mcp list` (Claude Code) or `codex mcp list` (Codex), looking for `speqq` or the plugin-provided `plugin:spec-kit:speqq`.
   - Listed already? The session just predates it. Skip to step 4.
   - Spec-Kit plugin installed (`claude plugin list` / `codex plugin list`)? The server ships with it. Skip to step 4, then run step 3 in the new session.
   - Truly missing? Register it, then go to step 3 for the first sign-in:
     - Claude Code: `claude mcp add --scope user --transport http speqq https://speqq.com/mcp`
     - Codex: `codex mcp add speqq --url https://speqq.com/mcp`. Run it if the harness allows, otherwise print it for the user.
3. **Authenticate if it's registered but not signed in.**
   - Claude Code: the agent can't do this part. Tell the user to run `/mcp`, select the `speqq` server, choose Authenticate, and finish the browser login.
   - Codex: run `codex mcp login speqq`. It opens the browser. If the sandbox refuses to run it, print the command for the user. If Codex answers that no such server exists, the server is plugin-owned: tell the user to authenticate it from the harness's MCP or plugin UI.
4. **Restart so it lands.** MCP servers and their auth load at session start. After registering or signing in, tell the user to start a new session, then re-run step 1 there. On Claude Code a fresh `/mcp` authentication sometimes takes effect live: if the tools answer without a restart, you're done; if not, the new session is the fix, not a deeper failure.
5. **Report.** One line per rung that ran: the check passed, or what was done about it, and the single action left for the user (new session, browser sign-in, or nothing).

## FYI

- Never ask for a token or password in chat. The browser sign-in is the whole flow.
- If sign-in keeps expiring and this ladder is being re-run often, say so in the report and tell the user to report it to Speqq. Repeated expiry is a server-side refresh problem, not something the user is doing wrong.
- Connection only. Hooks and the rest of machine setup come with the Spec-Kit plugin.
