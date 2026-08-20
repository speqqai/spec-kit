# Connect Speqq

Every Spec-Kit skill reads from and writes to a Speqq workspace over MCP. Nothing falls back to local files: each skill runs a preflight, and if the Speqq MCP tools are not available it stops and walks you through connecting. This page is the same setup, done once up front.

On Claude Code and Codex the spec-kit plugin registers the Speqq MCP server for you, so connecting is just signing in with your browser (OAuth). On a folders-only install, or on Cursor and Gemini CLI, you register the server yourself first, then sign in. A bearer token is the alternative — for service accounts, shared machines, and harnesses without an OAuth flow. The optional session-hook extras carry their own one-line credential, covered in [Session hooks](hooks.md).

The server is the same everywhere: **`https://speqq.com/mcp`** (streamable HTTP).

## 1. Sign in with OAuth — no token

### Claude Code

The plugin already registered the `speqq` server. Start a session, run `/mcp`, and authenticate `speqq` — your browser opens a Speqq login. Confirm with `claude mcp list`.

Installed the skills as folders instead of the plugin? Register the server first, then sign in as above:

```bash
claude mcp add --scope user --transport http speqq https://speqq.com/mcp
```

### Codex CLI

The plugin already registered the `speqq` server. Run `codex mcp login speqq` and finish the browser login. Streamable HTTP servers need Codex CLI 0.44.0 or newer; the pack is tested on 0.147.0. Confirm with `codex mcp list`, then start a new session and check the Speqq tools load.

Installed the skills as folders instead of the plugin? Register the server first:

```bash
codex mcp add speqq --url https://speqq.com/mcp
```

### Cursor and Gemini CLI

These harnesses have no plugin, so register the Speqq server by hand: add it to the harness's MCP configuration file (project-level or global) with the URL above. Use the harness's OAuth flow when it offers one, or the bearer-token form below when it does not. See that harness's MCP documentation for the exact schema.

## 2. Alternative: a bearer token

For service accounts, shared machines, or a harness that cannot OAuth. Create the token first:

1. In Speqq, open **Settings → MCP Tokens**.
2. Create a new token.
3. **Copy it immediately — it is shown once.** Treat it like a password: don't commit it, don't paste it into shared config or a conversation.

The token scopes the connection to your Speqq account; the skills resolve the workspace at runtime (they call `list_workspaces` first and ask which to use if you have several).

**Claude Code:**

```bash
claude mcp add --transport http speqq https://speqq.com/mcp \
  --header "Authorization: Bearer <your-token>"
```

**Codex CLI:**

```toml
[mcp_servers.speqq]
url = "https://speqq.com/mcp"
bearer_token_env_var = "SPEQQ_MCP_TOKEN"
```

Then export the token in your shell profile — Codex reads it from the environment at startup:

```bash
export SPEQQ_MCP_TOKEN="<your-token>"
```

Codex does not accept a literal bearer-token key in `config.toml`; the `bearer_token_env_var` indirection is the supported form, and it keeps the token out of the config file.

After editing configuration, restart the harness session so the tools load.

## 3. Verify the connection

Any of these confirms you're wired up:

- Ask your agent to **list Speqq workspaces**. A working connection returns your workspace(s); that call (`list_workspaces`) is also the first call every skill makes.
- Check your harness's MCP listing (for example `claude mcp list` in Claude Code) and confirm the Speqq server shows as connected.
- Just run a skill — e.g. "spec this feature" to trigger `spec-product`. The preflight verifies the connection before anything is written and guides you if it's missing.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Skill stops at preflight: "Speqq MCP is not connected" | The session started before the plugin installed, you have not signed in yet, or (folders-only install) the server was never registered | Sign in (`/mcp` or `codex mcp login speqq`) and start a new session; on a folders-only install, register the server first |
| Server registered but tools still missing | The session predates the OAuth login, or the login was never completed | Finish the browser login (`/mcp` authenticate in Claude Code, `codex mcp login speqq` in Codex), then start a new session |
| Speqq server listed but calls fail with an auth error | OAuth session expired, or a token was revoked or pasted incompletely | Re-run the browser login — or, on the token path, create a new token in **Settings → MCP Tokens** and update your harness config; the old value cannot be re-copied |
| Specs or queue items land in (or read from) the wrong workspace | You have several workspaces and the wrong one was chosen | Skills call `list_workspaces` first and ask which to use when there's more than one — name the workspace explicitly when the skill asks, or tell the agent which workspace to use up front |
| Speqq server not in the harness's MCP list at all | Config entry malformed (wrong key, wrong file, wrong scope) or the harness caches config | Re-check the entry against the harness's MCP docs, confirm the file location, restart the harness |
| A spec you expect isn't found | The skill is looking in a different workspace, or the title doesn't match — spec discovery is `spec_list` filtered by title | Confirm the workspace, then give the skill the spec's title (specs use commit-form titles like `feat: user auth`) |
