# shellcheck shell=sh
#
# spec-workspace-context.sh — SessionStart step: inject the workspace PRODUCT.md.
# Sourced by session-start.sh, never executed; defines run_workspace_context().
# Requires lib.sh sourced first ($WORK_DIR, post_rpc, the open MCP session).
#
# Read path (how the Speqq MCP API actually surfaces PRODUCT.md):
#   1. spec_orient (workspace_id + current git branch) returns a `product_file`
#      pointer {id, title} in structuredContent — the ONLY place that document
#      id is surfaced (spec_list returns specs; PRODUCT.md is not one), and
#      null when the workspace has not written a product file.
#   2. spec_read (spec_id = product_file.id) with no tab_id returns an index
#      whose `tabs` list names the page tab holding the product prose.
#   3. spec_read (spec_id + that tab_id) returns the markdown body at
#      structuredContent.content[tab_id].content_markdown.
#
# Invariants, same as every step under this dispatcher:
#   - never blocks: run_workspace_context() always returns 0
#   - never silent: every failure prints exactly ONE stderr line naming the cause
#   - stdout is sacred: the injection is buffered and printed whole or not at all
#   - PRODUCT ONLY: open work / rules / activity belong to a later hook, not here
#
# A workspace with no PRODUCT.md is a gap, not a failure: that path prints one
# stdout line so the agent can offer to create the file.

WC_STEP_NAME='speqq workspace-context'

# Cap on the injected PRODUCT.md body. Past it, the truncation note names the
# exact spec_read call that fetches the rest.
WC_MAX_PRODUCT_CHARS=6000

# ---------------------------------------------------------------------------
# Embedded python — one copy, request-builder and parser modes, double quotes
# only so it survives the single-quoted shell string. Parse modes read the
# response body on stdin; build modes never touch stdin.
# ---------------------------------------------------------------------------

WC_PYTHON='
import json
import sys

MODE = sys.argv[1]


def fail(message, code=1):
    sys.stderr.write(message.replace("\n", " ") + "\n")
    raise SystemExit(code)


def clip(value, limit):
    text = str(value)
    return text if len(text) <= limit else text[:limit] + "..."


def reply(raw):
    """Last JSON-RPC reply in the body. Streamable HTTP answers with SSE
    (data: lines) or a bare JSON object; both are read the same way."""
    chunks = []
    buffer = []
    for line in raw.splitlines():
        if line.startswith("data:"):
            buffer.append(line[5:].lstrip())
        elif not line.strip() and buffer:
            chunks.append("\n".join(buffer))
            buffer = []
    if buffer:
        chunks.append("\n".join(buffer))
    if not chunks:
        chunks = [raw]
    messages = [json.loads(chunk) for chunk in chunks if chunk.strip()]
    replies = [m for m in messages if "result" in m or "error" in m]
    if not replies:
        fail("the server sent no JSON-RPC reply")
    return replies[-1]


def text_of(result):
    parts = result.get("content", [])
    return "".join(p.get("text", "") for p in parts if p.get("type") == "text")


def structured_of(raw, label):
    message = reply(raw)
    if "error" in message:
        fail(label + " returned an RPC error: " + clip(json.dumps(message["error"]), 240))
    result = message["result"]
    if result.get("isError"):
        fail(label + " returned an error: " + clip(text_of(result), 240))
    payload = result.get("structuredContent")
    if payload is None:
        fail(label + " returned no structuredContent")
    return payload


def build_request(request_id, tool, arguments):
    sys.stdout.write(
        json.dumps(
            {
                "jsonrpc": "2.0",
                "id": request_id,
                "method": "tools/call",
                "params": {"name": tool, "arguments": arguments},
            }
        )
    )


raw_body = "" if MODE.startswith("build-") else sys.stdin.read()

if MODE == "build-orient":
    arguments = {"workspace_id": sys.argv[2]}
    if sys.argv[3]:
        arguments["branch"] = sys.argv[3]
    build_request(4, "spec_orient", arguments)
elif MODE == "build-read-index":
    build_request(5, "spec_read", {"spec_id": sys.argv[2]})
elif MODE == "build-read-page":
    build_request(6, "spec_read", {"spec_id": sys.argv[2], "tab_id": sys.argv[3]})
elif MODE == "pointer":
    # spec_orient -> the PRODUCT.md pointer. Exit 10 is the one non-error miss:
    # the workspace has no product file, and the caller says so on stdout.
    pointer = structured_of(raw_body, "spec_orient").get("product_file")
    if pointer is None:
        raise SystemExit(10)
    if not isinstance(pointer, dict) or not pointer.get("id"):
        fail("spec_orient returned a product_file with no id")
    sys.stdout.write(str(pointer["id"]) + "\n")
elif MODE == "page-tab":
    # spec_read index -> the first page tab, where the product prose lives.
    tabs = structured_of(raw_body, "spec_read").get("tabs")
    if not isinstance(tabs, list):
        fail("spec_read returned no tab list for the product file")
    pages = [t for t in tabs if isinstance(t, dict) and t.get("kind") == "page" and t.get("id")]
    if not pages:
        fail("the product file has no page tab to read")
    sys.stdout.write(str(pages[0]["id"]) + "\n")
elif MODE == "render":
    # spec_read page -> header plus the markdown body, capped at max chars with
    # a note naming the exact call that fetches the rest.
    spec_id, tab_id, max_chars = sys.argv[2], sys.argv[3], int(sys.argv[4])
    content = structured_of(raw_body, "spec_read").get("content")
    tab = content.get(tab_id) if isinstance(content, dict) else None
    if not isinstance(tab, dict) or "content_markdown" not in tab:
        fail("spec_read returned no content_markdown for the product page tab")
    body = str(tab["content_markdown"]).strip()
    lines = ["PRODUCT.md (workspace product brief):"]
    if not body:
        lines.append("(empty)")
    elif len(body) <= max_chars:
        lines.append(body)
    else:
        lines.append(body[:max_chars])
        lines.append(
            "[truncated: showing {0} of {1} characters - fetch the full document with "
            "spec_read (spec_id {2}, tab_id {3})]".format(max_chars, len(body), spec_id, tab_id)
        )
    sys.stdout.write("\n".join(lines) + "\n")
else:
    fail("unknown parser mode: " + MODE)
'

# ---------------------------------------------------------------------------
# Helpers, all wc_-prefixed so nothing in lib.sh or a sibling step is clobbered
# ---------------------------------------------------------------------------

# The only way this step reports trouble: one stderr line, non-zero return.
# Callers must never pass the token into `reason`.
wc_fail() {
  printf '%s: %s\n' "$WC_STEP_NAME" "$1" >&2
  return 1
}

# Parse the last response body. On failure the parser's own last stderr line
# becomes the diagnostic, so the single line names the real cause.
wc_parse() {
  python3 -c "$WC_PYTHON" "$@" <"$WORK_DIR/response" 2>"$WORK_DIR/wc-parse-error"
}

wc_parse_error_line() {
  tail -n 1 "$WORK_DIR/wc-parse-error" 2>/dev/null
}

# Empty outside a repo, on a detached HEAD, or without git — all cases where
# the honest answer is no branch at all. spec_orient treats that as information.
wc_current_branch() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi
  git branch --show-current 2>/dev/null || :
}

# The whole step. Every failure prints one line through wc_fail and returns
# non-zero; run_workspace_context() swallows that so the dispatcher continues.
wc_main() {
  if [ -z "${WORK_DIR:-}" ]; then
    wc_fail 'no work directory - lib.sh must be sourced and initialised first'
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    wc_fail 'python3 is not on PATH'
    return 1
  fi

  wc_workspace_id=${WORKSPACE_ID:-${SPEQQ_WORKSPACE_ID:-}}
  if [ -z "$wc_workspace_id" ]; then
    wc_fail 'no workspace id was resolved before this step'
    return 1
  fi

  # 1. spec_orient — the only call that surfaces the PRODUCT.md pointer.
  if ! python3 -c "$WC_PYTHON" build-orient "$wc_workspace_id" "$(wc_current_branch)" >"$WORK_DIR/request"; then
    wc_fail 'could not build the spec_orient request'
    return 1
  fi
  if ! post_rpc "$WORK_DIR/request" "$WORK_DIR/response"; then
    wc_fail "spec_orient failed (${HTTP_STATUS:-unknown})"
    return 1
  fi
  wc_pointer_status=0
  wc_product_id=$(wc_parse pointer) || wc_pointer_status=$?
  if [ "$wc_pointer_status" -eq 10 ]; then
    printf 'No PRODUCT.md exists in this workspace yet - the agent may offer to create one from the Context panel in Speqq or over MCP.\n'
    return 0
  fi
  if [ "$wc_pointer_status" -ne 0 ]; then
    wc_fail "could not read the product file pointer: $(wc_parse_error_line)"
    return 1
  fi

  # 2. spec_read index — find the page tab that holds the product prose.
  if ! python3 -c "$WC_PYTHON" build-read-index "$wc_product_id" >"$WORK_DIR/request"; then
    wc_fail 'could not build the spec_read index request'
    return 1
  fi
  if ! post_rpc "$WORK_DIR/request" "$WORK_DIR/response"; then
    wc_fail "spec_read of the product file index failed (${HTTP_STATUS:-unknown})"
    return 1
  fi
  if ! wc_page_tab=$(wc_parse page-tab); then
    wc_fail "could not find the product file page tab: $(wc_parse_error_line)"
    return 1
  fi

  # 3. spec_read page — the markdown body itself.
  if ! python3 -c "$WC_PYTHON" build-read-page "$wc_product_id" "$wc_page_tab" >"$WORK_DIR/request"; then
    wc_fail 'could not build the spec_read page request'
    return 1
  fi
  if ! post_rpc "$WORK_DIR/request" "$WORK_DIR/response"; then
    wc_fail "spec_read of the product page failed (${HTTP_STATUS:-unknown})"
    return 1
  fi

  # Render into a buffer first: stdout receives the injection whole or not at
  # all — a parse failure after a partial print would leak a broken fragment
  # into session context.
  if ! wc_parse render "$wc_product_id" "$wc_page_tab" "$WC_MAX_PRODUCT_CHARS" >"$WORK_DIR/wc-render"; then
    wc_fail "could not read the product page content: $(wc_parse_error_line)"
    return 1
  fi
  cat "$WORK_DIR/wc-render"
}

# Contract entry point: the dispatcher calls this and must always continue.
run_workspace_context() {
  wc_main || :
  return 0
}
