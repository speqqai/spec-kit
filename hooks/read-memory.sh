#!/bin/sh
#
# read-memory.sh — fires ONCE per window at the same near-empty rung as
# read-product-context.sh (measured context fill below
# SPEQQ_CONTEXT_ORIENT_PCT, default 10). Injects one instruction telling the
# LIVE agent to catch up on the active spec's memory over its OWN Speqq MCP
# connection: resolve the active spec from the current git branch with
# spec_orient, then spec_memory_read it to read the story so far.
#
# Tokenless: this hook opens no MCP connection, resolves no credentials, and
# makes no network call. It only measures the local transcript (in lib.sh) and
# prints an instruction. Every path exits 0; stdout carries the injection only
# when the rung fires; a runtime failure prints one stderr line.

set -u

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 0
[ -f "$SCRIPT_DIR/lib.sh" ] || exit 0
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
[ -f "$SCRIPT_DIR/memory-lib.sh" ] || exit 0
# shellcheck source=memory-lib.sh
. "$SCRIPT_DIR/memory-lib.sh"

RM_ORIENT_PCT=${SPEQQ_CONTEXT_ORIENT_PCT:-10}
RM_SHARED_HANDLE=$(speqq_memory_handle) || exit 0
if [ -n "$RM_SHARED_HANDLE" ]; then
  RM_TEMPLATE="Catch up before you continue: call list_workspaces, then use the Speqq Knowledge MCP memory_read with that workspace_id and handle \"$RM_SHARED_HANDLE\" (without @). Read its summary and newest durable entries; use memory_search for older details. If the Knowledge MCP is unavailable, report that and continue from the spec and repo."
  speqq_run read read-memory "$RM_ORIENT_PCT" "$RM_TEMPLATE" ''
  exit 0
fi

RM_BRANCH=$(git branch --show-current 2>/dev/null) || RM_BRANCH=''

if [ -n "$RM_BRANCH" ]; then
  RM_RESOLVE="call spec_orient with branch \"$RM_BRANCH\" to resolve the active spec"
else
  RM_RESOLVE="call spec_orient with the current git branch to resolve the active spec"
fi

RM_TEMPLATE="Catch up before you continue: read the active spec's memory. Over your own Speqq MCP connection, $RM_RESOLVE, then call spec_memory_read on it to read the story of the work so far. If the Speqq MCP tools are not available in this session, skip this and continue."

speqq_run read read-memory "$RM_ORIENT_PCT" "$RM_TEMPLATE" ''
