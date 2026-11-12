#!/usr/bin/env python3
"""Structural validation for Speqq's plugin marketplace and built-in skills.

Checks:
  - both marketplaces list one plugin, `speqq`, sourced from ./plugins/speqq
  - the plugin manifests parse, declare the /mcp server, and have no hooks or skills
  - each skills/*/SKILL.md frontmatter parses as YAML (a stray unquoted ": " in a
    description silently drops the metadata), name == directory, non-empty
    description, no em dash
Exits non-zero with a list of problems, or prints a success line.
"""
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML is required. Install it with `python3 -m pip install pyyaml`.", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []
EM_DASH = "—"
MCP_URL = "https://speqq.com/mcp"


def load(rel: str):
    try:
        return json.loads((ROOT / rel).read_text())
    except Exception as exc:  # noqa: BLE001 - report any read or parse failure
        errors.append(f"{rel}: {exc}")
        return None


# 1. Marketplaces point at the one plugin.
for rel in [".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"]:
    data = load(rel)
    if data is None:
        continue
    plugins = data.get("plugins", [])
    if data.get("name") != "speqq":
        errors.append(f"{rel}: marketplace name must be 'speqq'")
    if len(plugins) != 1 or plugins[0].get("name") != "speqq" or plugins[0].get("source") != "./plugins/speqq":
        errors.append(f"{rel}: must list exactly one plugin 'speqq' with source './plugins/speqq'")

# 2. Plugin manifests: MCP only.
for rel in ["plugins/speqq/.claude-plugin/plugin.json", "plugins/speqq/.codex-plugin/plugin.json"]:
    data = load(rel)
    if data is None:
        continue
    if data.get("name") != "speqq":
        errors.append(f"{rel}: name must be 'speqq'")
    for banned in ("hooks", "skills"):
        if banned in data:
            errors.append(f"{rel}: must not declare '{banned}'")
claude = load("plugins/speqq/.claude-plugin/plugin.json")
if claude and claude.get("mcpServers", {}).get("speqq", {}).get("url") != MCP_URL:
    errors.append(f"claude plugin.json: mcpServers.speqq.url must be {MCP_URL}")
codex_mcp = load("plugins/speqq/.codex-plugin/mcp.json")
if codex_mcp and codex_mcp.get("mcpServers", {}).get("speqq", {}).get("url") != MCP_URL:
    errors.append(f"codex mcp.json: mcpServers.speqq.url must be {MCP_URL}")
for stray in ("skills", "hooks"):
    if (ROOT / "plugins/speqq" / stray).exists():
        errors.append(f"plugins/speqq/{stray} must not exist")

# 3. Built-in skills.
for skill in sorted(p for p in (ROOT / "skills").iterdir() if p.is_dir()):
    md = skill / "SKILL.md"
    if not md.exists():
        errors.append(f"{skill.name}: missing SKILL.md")
        continue
    text = md.read_text()
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        errors.append(f"{skill.name}: no frontmatter block")
        continue
    try:
        meta = yaml.safe_load(match.group(1))
    except yaml.YAMLError as exc:
        errors.append(f"{skill.name}: frontmatter is not valid YAML ({exc})")
        continue
    if not isinstance(meta, dict):
        errors.append(f"{skill.name}: frontmatter is not a YAML mapping")
        continue
    if meta.get("name") != skill.name:
        errors.append(f"{skill.name}: name {meta.get('name')!r} does not match directory")
    if not (meta.get("description") and str(meta["description"]).strip()):
        errors.append(f"{skill.name}: missing or empty description")
    for lineno, line in enumerate(text.splitlines(), 1):
        if EM_DASH in line:
            errors.append(f"{skill.name}: em dash at SKILL.md line {lineno}")
            break

if errors:
    print("VALIDATION FAILED:")
    for problem in errors:
        print(f"  - {problem}")
    sys.exit(1)

print("All marketplace and skill validation checks passed.")
