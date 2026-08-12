# Connect Speqq

Every Spec-Kit skill reads from and writes to a Speqq workspace over MCP. Nothing falls back to local files: each skill runs a preflight, and if the Speqq MCP tools are not available it stops and walks you through connecting. This page is the same setup, done once up front.

Connecting takes two steps — create an MCP token in Speqq, then add the Speqq MCP server to your harness — plus a quick check that it worked.

## 1. Create an MCP token

1. In Speqq, open **Settings → MCP Tokens**.
2. Create a new token.
3. **Copy it immediately — it is shown once.** Treat it like a password: don't commit it, don't paste it into shared config.

The token scopes the connection to your Speqq account; the skills resolve the workspace at runtime (they call `list_workspaces` first and ask you which to use if you have several).

## 2. Add the Speqq MCP server to your harness

You need two values everywhere:

- **URL:** `https://speqq.com/mcp` (HTTP transport)
- **Auth:** your token as an `Authorization: Bearer <token>` header

The exact mechanics differ per harness.

### Claude Code

```bash
claude mcp add --transport http speqq https://speqq.com/mcp \
  --header "Authorization: Bearer <your-token>"
```

Add `--scope user` to register it for every project instead of just the current one. Confirm with `claude mcp list`.

### Codex CLI

Add the Speqq server to `~/.codex/config.toml` (or a trusted project's `.codex/config.toml`):

```toml
[mcp_servers.speqq]
url = "https://speqq.com/mcp"
bearer_token_env_var = "SPEQQ_MCP_TOKEN"
```

Then export the token in your shell profile — Codex reads it from the environment at startup:

```bash
export SPEQQ_MCP_TOKEN="<your-token>"
```

Codex does not accept a literal bearer-token key in `config.toml`; the `bearer_token_env_var` indirection is the supported form, and it keeps the token out of the config file. This is the same value the session hooks read from the credentials file, living in its second home. Streamable HTTP servers need Codex CLI 0.44.0 or newer. Confirm with `codex mcp list`, then start a new session and check the Speqq tools load.

### Cursor

Add the Speqq server to Cursor's MCP configuration file (project-level or global `mcp.json`) with the URL and an authorization header carrying the bearer token. See Cursor's MCP documentation for the exact schema.

### Gemini CLI

Add the Speqq server under the MCP servers section of the Gemini CLI settings file, with the URL and bearer token. See the Gemini CLI MCP documentation for the exact entry format.

After editing configuration, restart the harness session so the tools load.

## 3. Verify the connection

Any of these confirms you're wired up:

- Ask your agent to **list Speqq workspaces**. A working connection returns your workspace(s); that call (`list_workspaces`) is also the first call every skill makes.
- Check your harness's MCP listing (for example `claude mcp list` in Claude Code) and confirm the Speqq server shows as connected.
- Just run a skill — e.g. "spec this feature" to trigger `spec-product`. The preflight verifies the connection before anything is written and guides you if it's missing.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Skill stops at preflight: "Speqq MCP is not connected" | Server not added to this harness, added under a different scope (project vs. global), or session started before the config change | Add the server for the harness you're using, then restart the session so tools load |
| Speqq server listed but calls fail with an auth error | Token expired, revoked, or pasted incompletely | Create a new token in **Settings → MCP Tokens** and update your harness config with it — the old value cannot be re-copied |
| Specs or queue items land in (or read from) the wrong workspace | You have several workspaces and the wrong one was chosen | Skills call `list_workspaces` first and ask which to use when there's more than one — name the workspace explicitly when the skill asks, or tell the agent which workspace to use up front |
| Speqq server not in the harness's MCP list at all | Config entry malformed (wrong key, wrong file, wrong scope) or the harness caches config | Re-check the entry against the harness's MCP docs, confirm the file location, restart the harness |
| A spec you expect isn't found | The skill is looking in a different workspace, or the title doesn't match — spec discovery is `spec_list` filtered by title | Confirm the workspace, then give the skill the spec's title (specs use commit-form titles like `feat: user auth`) |
