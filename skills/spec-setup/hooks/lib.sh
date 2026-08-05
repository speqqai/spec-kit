# shellcheck shell=sh
#
# lib.sh — shared plumbing for the Speqq session-start dispatcher.
# Sourced by session-start.sh from its own directory; never executed.
#
# What lives here: credentials resolution (environment first, then the
# credentials file), the hook stdin parse, the shared wall-clock deadline,
# the private work directory, the curl config carrying the bearer token,
# the MCP session (initialize -> notifications/initialized -> tools/call
# over Streamable HTTP JSON-RPC), workspace resolution, and response
# parsing.
#
# Invariants every function upholds:
#
# 1. NEVER BLOCK A SESSION. Every failure path exits 0 (see give_up).
# 2. NEVER FAIL SILENTLY. Every failure prints exactly ONE stderr line
#    naming the cause; a missing variable is named as itself.
# 3. NEVER LEAK THE TOKEN. The token lands only in a chmod-600 curl config
#    inside a mktemp directory removed on exit — never on a command line
#    (where ps would show it), never on stdout, never in a diagnostic.
# 4. ONE DEADLINE. All requests share one wall-clock budget
#    (SPEQQ_HOOK_TIMEOUT_SECONDS, default 8 seconds) — a slow server costs
#    a session that much in total, not per request.
# 5. STDOUT IS SACRED. Only intentional context-injection text goes there.
#
# Requires: curl, python3 (both checked by the dispatcher before use).

case ${0##*/} in
lib.sh)
  printf 'speqq session-start: lib.sh is a library - run session-start.sh instead\n' >&2
  exit 0
  ;;
esac

HOOK_NAME='speqq session-start'

# Whole-run budget shared across every request the dispatcher makes, and the
# floor under which a further request is not worth issuing.
DEFAULT_TIMEOUT_SECONDS=8
MIN_REQUEST_SECONDS=0.25

MCP_PROTOCOL_VERSION='2025-03-26'
CLIENT_NAME='speqq-session-start'
CLIENT_VERSION='1'

WORK_DIR=''
RPC_ID=1 # id 1 belongs to initialize; call_tool allocates upward from here

# ---------------------------------------------------------------------------
# Embedded python — invoked with a body on stdin or arguments on argv.
# Written with double quotes only so it survives single-quoted shell.
# ---------------------------------------------------------------------------

# Generic JSON-RPC response reader. Modes:
#   workspaces <label> — emit one `<uuid>\t<name>` line per visible workspace
#   text <label>       — emit the text content of a successful tools/call
#   structured <label> — emit the structuredContent of the result as JSON
# shellcheck disable=SC2016 # single quotes are the point: python, not shell
PYTHON_PARSE='
import json
import re
import sys

MODE = sys.argv[1]
LABEL = sys.argv[2] if len(sys.argv) > 2 else MODE


def fail(message):
    sys.stderr.write(message.replace("\n", " ") + "\n")
    raise SystemExit(1)


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


def result_of(raw, label):
    message = reply(raw)
    if "error" in message:
        fail(label + " returned an RPC error: " + clip(json.dumps(message["error"]), 240))
    result = message["result"]
    if result.get("isError"):
        fail(label + " returned an error: " + clip(text_of(result), 240))
    return result


def render_workspaces(result):
    """list_workspaces answers in text: `- <name> (<uuid>)[: description]`."""
    for line in text_of(result).splitlines():
        match = re.match(r"^- (.+?) \(([0-9a-fA-F-]{36})\)", line)
        if match:
            sys.stdout.write(match.group(2) + "\t" + match.group(1) + "\n")


raw_body = sys.stdin.read()
if MODE == "workspaces":
    render_workspaces(result_of(raw_body, LABEL))
elif MODE == "text":
    text = text_of(result_of(raw_body, LABEL))
    if text and not text.endswith("\n"):
        text = text + "\n"
    sys.stdout.write(text)
elif MODE == "structured":
    payload = result_of(raw_body, LABEL).get("structuredContent")
    if payload is None:
        fail(LABEL + " returned no structuredContent")
    sys.stdout.write(json.dumps(payload))
else:
    fail("unknown parser mode: " + MODE)
'

# Build one tools/call request: argv = id, tool name, JSON arguments object.
PYTHON_BUILD_CALL='
import json
import sys

arguments = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else {}
if not isinstance(arguments, dict):
    raise SystemExit("tool arguments must be a JSON object")
sys.stdout.write(
    json.dumps(
        {
            "jsonrpc": "2.0",
            "id": int(sys.argv[1]),
            "method": "tools/call",
            "params": {"name": sys.argv[2], "arguments": arguments},
        }
    )
)
'

# The hook payload on stdin: two lines out (session_id, then source), each
# empty when missing, malformed, or suspicious. Never fatal, never blocking —
# a TTY stdin (a human running the script by hand) reads as no payload.
PYTHON_STDIN='
import json
import re
import sys

raw = "" if sys.stdin.isatty() else sys.stdin.read()
try:
    payload = json.loads(raw)
except ValueError:
    payload = {}
if not isinstance(payload, dict):
    payload = {}


def field(name, pattern):
    value = payload.get(name, "")
    if not isinstance(value, str):
        return ""
    return value if re.fullmatch(pattern, value) else ""


sys.stdout.write(field("session_id", r"[A-Za-z0-9._-]{1,128}") + "\n")
sys.stdout.write(field("source", r"[a-z]{1,32}") + "\n")
'

PYTHON_DEADLINE='
import sys
import time

sys.stdout.write("%.3f" % (time.time() + float(sys.argv[1])))
'

PYTHON_SECONDS_LEFT='
import sys
import time

left = float(sys.argv[1]) - time.time()
if left < float(sys.argv[2]):
    raise SystemExit(1)
sys.stdout.write("%.2f" % left)
'

# ---------------------------------------------------------------------------
# Exit paths
# ---------------------------------------------------------------------------

# The only way this hook reports trouble: one line, then a clean exit so the
# session proceeds. Callers must never pass the token into `reason`.
give_up() {
  printf '%s: %s\n' "$HOOK_NAME" "$1" >&2
  exit 0
}

cleanup() {
  if [ -n "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
  fi
}

# ---------------------------------------------------------------------------
# Hook stdin
# ---------------------------------------------------------------------------

# Parse the harness hook payload ONCE. The two fields every step may need are
# exported; anything missing or unparseable becomes the empty string.
parse_hook_stdin() {
  SPEQQ_HARNESS_SESSION_ID=''
  SPEQQ_SESSION_SOURCE=''
  if command -v python3 >/dev/null 2>&1; then
    stdin_fields=$(python3 -c "$PYTHON_STDIN" 2>/dev/null) || stdin_fields=''
    SPEQQ_HARNESS_SESSION_ID=$(printf '%s\n' "$stdin_fields" | sed -n '1p')
    SPEQQ_SESSION_SOURCE=$(printf '%s\n' "$stdin_fields" | sed -n '2p')
  fi
  export SPEQQ_HARNESS_SESSION_ID SPEQQ_SESSION_SOURCE
}

# ---------------------------------------------------------------------------
# Credentials — the bridge between "the user connected Speqq" and this hook.
# Environment variables win when set; each one still missing is read from a
# dotenv-style credentials file (three SPEQQ_* KEY=value lines). The file is
# parsed, never sourced: a credentials file must never execute.
# ---------------------------------------------------------------------------

# $1 = key. Last assignment wins; the value is everything after the first
# `=`, verbatim apart from stray carriage returns. The token only ever flows
# through this pipe into a shell variable — never onto a command line.
credential_from_file() {
  grep "^$1=" "$SPEQQ_CREDENTIALS_PATH" 2>/dev/null | tail -n 1 | cut -d '=' -f 2- | tr -d '\r'
}

# Sets SPEQQ_CONNECTED=1 when a URL and token are resolved, 0 when neither
# exists anywhere (the not-connected case speqq-setup.sh turns into setup
# guidance). A half-configured state names the missing variable and gives up.
resolve_credentials() {
  SPEQQ_CREDENTIALS_PATH=${SPEQQ_CREDENTIALS_FILE:-$HOME/.speqq/credentials}
  if [ -f "$SPEQQ_CREDENTIALS_PATH" ]; then
    # ls reads the mode string only — no filename parsing, so SC2012 does
    # not apply, and `stat` flag syntax differs between BSD and GNU.
    # shellcheck disable=SC2012
    file_mode=$(ls -ld "$SPEQQ_CREDENTIALS_PATH" 2>/dev/null | cut -c5-10)
    if [ -n "$file_mode" ] && [ "$file_mode" != '------' ]; then
      printf '%s: %s is readable by the group or others - run: chmod 600 %s\n' \
        "$HOOK_NAME" "$SPEQQ_CREDENTIALS_PATH" "$SPEQQ_CREDENTIALS_PATH" >&2
    fi
    [ -n "${SPEQQ_MCP_URL:-}" ] || SPEQQ_MCP_URL=$(credential_from_file SPEQQ_MCP_URL)
    [ -n "${SPEQQ_MCP_TOKEN:-}" ] || SPEQQ_MCP_TOKEN=$(credential_from_file SPEQQ_MCP_TOKEN)
    [ -n "${SPEQQ_WORKSPACE_ID:-}" ] || SPEQQ_WORKSPACE_ID=$(credential_from_file SPEQQ_WORKSPACE_ID)
  fi

  if [ -z "${SPEQQ_MCP_URL:-}" ] && [ -z "${SPEQQ_MCP_TOKEN:-}" ]; then
    SPEQQ_CONNECTED=0
    return 0
  fi
  if [ -z "${SPEQQ_MCP_URL:-}" ]; then
    give_up 'SPEQQ_MCP_TOKEN is set but SPEQQ_MCP_URL is not - set both, in the environment or the credentials file'
  fi
  if [ -z "${SPEQQ_MCP_TOKEN:-}" ]; then
    give_up 'SPEQQ_MCP_URL is set but SPEQQ_MCP_TOKEN is not - set both, in the environment or the credentials file'
  fi
  # shellcheck disable=SC2034 # read by session-start.sh and speqq-setup.sh
  SPEQQ_CONNECTED=1
}

# ---------------------------------------------------------------------------
# Deadline, work directory, curl config
# ---------------------------------------------------------------------------

start_deadline() {
  TIMEOUT_SECONDS=${SPEQQ_HOOK_TIMEOUT_SECONDS:-$DEFAULT_TIMEOUT_SECONDS}
  case $TIMEOUT_SECONDS in
  '' | . | *[!0-9.]* | *.*.*)
    give_up "SPEQQ_HOOK_TIMEOUT_SECONDS is not a number of seconds: $TIMEOUT_SECONDS"
    ;;
  esac
  DEADLINE=$(python3 -c "$PYTHON_DEADLINE" "$TIMEOUT_SECONDS") ||
    give_up 'could not read the clock'
}

make_work_dir() {
  WORK_DIR=$(mktemp -d) || give_up 'could not create a temporary directory'
  trap cleanup EXIT HUP INT TERM
  CURL_CONFIG="$WORK_DIR/curl.conf"
  HEADER_FILE="$WORK_DIR/headers"
}

# curl's config parser splits an option from its value on `:` as well as `=`,
# so a header value MUST be quoted or the whole line is dropped and the
# request goes out unauthenticated. Quoted values process backslash escapes,
# hence config_escape on the token.
write_curl_config() {
  : >"$CURL_CONFIG"
  chmod 600 "$CURL_CONFIG"
  {
    printf 'header = "Authorization: Bearer %s"\n' "$(config_escape "$SPEQQ_MCP_TOKEN")"
    printf 'header = "Content-Type: application/json"\n'
    printf 'header = "Accept: application/json, text/event-stream"\n'
  } >>"$CURL_CONFIG"
}

# ---------------------------------------------------------------------------
# Transport
# ---------------------------------------------------------------------------

# Backslash and double quote, the two characters a quoted curl config value
# reads as escapes. Runs in-process: the value never reaches a command line.
config_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Fractional seconds left of the shared budget, or non-zero once it is spent.
# Whole seconds would not do: `date` gives no sub-second precision on BSD, so
# integer math hands the last request a full second more than remains and the
# hook overshoots its own cap. MIN_REQUEST_SECONDS is the floor below which a
# request cannot finish anyway, so issuing it would only burn the tail.
seconds_left() {
  python3 -c "$PYTHON_SECONDS_LEFT" "$DEADLINE" "$MIN_REQUEST_SECONDS"
}

# POST one JSON-RPC message: $1 = request body file, $2 = response body file.
# Returns non-zero on transport failure, on a non-2xx status, or once the
# shared deadline is spent. HTTP_STATUS carries the code for the diagnostic.
post_rpc() {
  budget=$(seconds_left) || {
    HTTP_STATUS='out of time'
    return 1
  }
  HTTP_STATUS=$(
    curl --silent --config "$CURL_CONFIG" --request POST "$SPEQQ_MCP_URL" \
      --max-time "$budget" \
      --dump-header "$HEADER_FILE" \
      --output "$2" \
      --write-out '%{http_code}' \
      --data-binary "@$1"
  ) || {
    HTTP_STATUS='no response'
    return 1
  }
  case "$HTTP_STATUS" in
  2*) return 0 ;;
  *) return 1 ;;
  esac
}

# initialize, capture the session id the transport hands back, then send the
# initialized notification. A server that issues no session id is running
# stateless and needs no echo — that is the protocol, not a degraded mode.
open_session() {
  printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"%s","capabilities":{},"clientInfo":{"name":"%s","version":"%s"}}}' \
    "$MCP_PROTOCOL_VERSION" "$CLIENT_NAME" "$CLIENT_VERSION" >"$WORK_DIR/request"
  post_rpc "$WORK_DIR/request" "$WORK_DIR/response" ||
    give_up "initialize failed against $SPEQQ_MCP_URL ($HTTP_STATUS)"

  session_id=$(grep -i '^mcp-session-id:' "$HEADER_FILE" | tail -n 1 | tr -d '\r' | sed 's/^[^:]*:[[:space:]]*//')
  if [ -n "$session_id" ]; then
    printf 'header = "mcp-session-id: %s"\n' "$(config_escape "$session_id")" >>"$CURL_CONFIG"
  fi

  printf '{"jsonrpc":"2.0","method":"notifications/initialized"}' >"$WORK_DIR/request"
  post_rpc "$WORK_DIR/request" "$WORK_DIR/response" ||
    give_up "the initialized notification failed ($HTTP_STATUS)"
}

# Build and POST one tools/call on the open session. $1 = tool name, $2 =
# JSON arguments object (defaults to {}), $3 = label for diagnostics
# (defaults to the tool name). The response lands in $WORK_DIR/response.
call_tool() {
  RPC_ID=$((RPC_ID + 1))
  tool_name=$1
  tool_args=${2:-}
  tool_label=${3:-$1}
  [ -n "$tool_args" ] || tool_args='{}'
  python3 -c "$PYTHON_BUILD_CALL" "$RPC_ID" "$tool_name" "$tool_args" >"$WORK_DIR/request" 2>/dev/null ||
    give_up "could not build the $tool_label request"
  post_rpc "$WORK_DIR/request" "$WORK_DIR/response" ||
    give_up "$tool_label failed ($HTTP_STATUS)"
}

# Parse the response body in $WORK_DIR/response: $1 = mode, $2 = label. On
# failure the parser's own last stderr line becomes the diagnostic, so the
# single reported line names the real cause.
parse_response() {
  python3 -c "$PYTHON_PARSE" "$@" <"$WORK_DIR/response" 2>"$WORK_DIR/parse-error"
}

parse_error_line() {
  tail -n 1 "$WORK_DIR/parse-error" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Workspace
# ---------------------------------------------------------------------------

# SPEQQ_WORKSPACE_ID wins when set. Otherwise the workspace is read from the
# server and used only when there is exactly one — several workspaces is an
# ambiguity the user resolves, never one this hook picks. The list is fetched
# either way: it is the only source of the workspace NAME the setup line
# prints, and it proves the token works before any step spends the budget.
resolve_workspace() {
  call_tool list_workspaces '{}'
  parse_response workspaces list_workspaces >"$WORK_DIR/workspaces" ||
    give_up "could not read the workspace list: $(parse_error_line)"

  if [ -n "${SPEQQ_WORKSPACE_ID:-}" ]; then
    WORKSPACE_ID=$SPEQQ_WORKSPACE_ID
    WORKSPACE_NAME=$(awk -F '\t' -v id="$WORKSPACE_ID" '$1 == id { print $2; exit }' "$WORK_DIR/workspaces")
    if [ -z "$WORKSPACE_NAME" ]; then
      give_up "SPEQQ_WORKSPACE_ID $WORKSPACE_ID is not among the workspaces this token can see"
    fi
    return 0
  fi

  count=$(wc -l <"$WORK_DIR/workspaces" | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    give_up 'this token can see no workspaces - check SPEQQ_MCP_TOKEN belongs to a workspace member'
  fi
  if [ "$count" -gt 1 ]; then
    give_up "$count workspaces are visible - set SPEQQ_WORKSPACE_ID to the one this repo belongs to"
  fi
  WORKSPACE_ID=$(cut -f 1 <"$WORK_DIR/workspaces")
  WORKSPACE_NAME=$(cut -f 2 <"$WORK_DIR/workspaces")
}
