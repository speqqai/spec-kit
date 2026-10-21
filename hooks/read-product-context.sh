#!/bin/sh
#
# read-product-context.sh — fires ONCE per window at the near-empty rung
# (measured context fill below SPEQQ_CONTEXT_ORIENT_PCT, default 10). Injects
# one instruction telling the LIVE agent to orient by reading the product
# context over its OWN Speqq MCP connection with get_context. Reads product
# context only; read-memory.sh handles the active work.
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

RPC_ORIENT_PCT=${SPEQQ_CONTEXT_ORIENT_PCT:-10}

RPC_TEMPLATE='Orient before you start: over your own Speqq MCP connection, call list_workspaces, then get_context with the selected workspace_id for product and repository context. If get_context is unavailable, continue from the repo and the active spec without inventing a product_file pointer.'

speqq_run read read-product "$RPC_ORIENT_PCT" "$RPC_TEMPLATE" ''
