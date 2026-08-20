#!/bin/sh
#
# read-product-context.sh — fires ONCE per window at the near-empty rung
# (measured context fill below SPEQQ_CONTEXT_ORIENT_PCT, default 10). Injects
# one instruction telling the LIVE agent to orient by reading the product
# brief over its OWN Speqq MCP connection: call spec_orient for the
# product_file (PRODUCT.md) pointer and spec_read it. Reads the product node
# only — it never mentions the open or active work; read-memory.sh does that.
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

RPC_TEMPLATE='Orient before you start: read the product brief. Over your own Speqq MCP connection, call spec_orient and read the product_file pointer it returns (PRODUCT.md) with spec_read - what the product is, who it is for, and what must never break. Read the product node only. If the Speqq MCP tools are not available in this session, skip this and continue.'

speqq_run read read-product "$RPC_ORIENT_PCT" "$RPC_TEMPLATE" ''
