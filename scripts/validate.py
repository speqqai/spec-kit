#!/usr/bin/env python3
"""Structural validation for the Spec-Kit plugin.

Runs in CI and locally. Checks:
  - every bundled JSON file parses
  - VERSION matches both plugin manifests
  - each skill's frontmatter parses as YAML (this is what catches a stray
    unquoted ": " in a description, which silently drops the metadata at
    runtime), with name == directory and a non-empty description, no em dash
  - the four PostToolUse hook scripts are executable
Exits non-zero with a list of problems, or prints a success line.
"""
import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print(
        "PyYAML is required to validate skill frontmatter. Install it with "
        "`python3 -m pip install pyyaml`.",
        file=sys.stderr,
    )
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []

JSON_FILES = [
    ".claude-plugin/plugin.json",
    ".claude-plugin/marketplace.json",
    ".codex-plugin/plugin.json",
    ".codex-plugin/mcp.json",
    "hooks/claude.plugin.hooks.json",
    "hooks/codex.plugin.hooks.json",
]

HOOK_SCRIPTS = [
    "hooks/read-product-context.sh",
    "hooks/read-memory.sh",
    "hooks/append-memory.sh",
    "hooks/prefer-knowledge-graph.sh",
]

EM_DASH = "—"


def load_json(rel: str):
    return json.loads((ROOT / rel).read_text())


# 1. JSON parses.
for rel in JSON_FILES:
    path = ROOT / rel
    if not path.exists():
        errors.append(f"missing JSON file: {rel}")
        continue
    try:
        json.loads(path.read_text())
    except Exception as exc:  # noqa: BLE001 - report any parse failure
        errors.append(f"invalid JSON {rel}: {exc}")

# 2. Version markers agree.
try:
    version = (ROOT / "VERSION").read_text().strip()
    claude_version = load_json(".claude-plugin/plugin.json").get("version")
    codex_version = load_json(".codex-plugin/plugin.json").get("version")
    if not version == claude_version == codex_version:
        errors.append(
            "version mismatch: "
            f"VERSION={version} claude={claude_version} codex={codex_version}"
        )
except Exception as exc:  # noqa: BLE001
    errors.append(f"version check failed: {exc}")

# 3. Skills: frontmatter must parse as YAML, name == dir, description present.
skills_dir = ROOT / "skills"
for skill in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
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

# 4. Hook scripts are executable.
for rel in HOOK_SCRIPTS:
    path = ROOT / rel
    if not path.exists():
        errors.append(f"missing hook: {rel}")
    elif not os.access(path, os.X_OK):
        errors.append(f"hook not executable: {rel}")

if errors:
    print("VALIDATION FAILED:")
    for problem in errors:
        print(f"  - {problem}")
    sys.exit(1)

print("All plugin validation checks passed.")
