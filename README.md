# Speqq plugin marketplace

This repo is Speqq's plugin marketplace and the source of Speqq's built-in skills.

The marketplace lists one plugin, `speqq`. It does one thing: it connects your coding agent to Speqq's server at `https://speqq.com/mcp`. It contains no skills and no hooks.

## Install

Claude Code:

```
/plugin marketplace add speqqai/spec-kit
/plugin install speqq@speqq
```

Codex:

```
codex plugin marketplace add speqqai/spec-kit
codex plugin add speqq@speqq
```

Without a plugin:

```
claude mcp add --transport http speqq https://speqq.com/mcp
```

Sign in when prompted.

## What you get

- Speqq's tools, plus the tools of the apps you have connected to Speqq.
- The spec workflows (write-spec, scope-spec, review-spec, implement-spec, check-drift, review-code) as Speqq's slash commands. Type `/` and look for `speqq`.

## Upgrading from Spec-Kit

Run `/plugin uninstall spec-kit@speqq`, then install `speqq@speqq`. Spec-Kit's hooks and local skills are gone; the workflows now come from Speqq.

## Built-in skills

The folders in `skills/` are the source of Speqq's built-in skills. Speqq syncs them from `main`, so an edit there reaches every Speqq user within a day. Skills follow the [Agent Skills](https://agentskills.io) format: a `SKILL.md` with `name` and `description` front matter.

## Help

https://speqq.com/docs/skills
