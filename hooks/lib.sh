# shellcheck shell=sh
#
# lib.sh — shared plumbing for the four capacity-driven PostToolUse hooks
# (read-product-context.sh, read-memory.sh, append-memory.sh source it;
# prefer-knowledge-graph.sh does not need it). Sourced from each hook's own
# directory; never executed.
#
# What lives here, and ONLY this:
#   1. The context-fill measurement — one python pass over the transcript
#      TAIL, reading the last usage-bearing record. Two transcript shapes,
#      each self-identifying (no harness flag decides the parse):
#        - Claude Code JSONL: assistant records carrying message.usage
#          (input_tokens + cache_creation_input_tokens + cache_read_input_tokens).
#        - Codex rollouts: event_msg records with payload.type "token_count",
#          whose info.last_token_usage.input_tokens is the last request's
#          prompt size and whose info.model_context_window names the window.
#      The denominator is SPEQQ_CONTEXT_WINDOW when set, else the window the
#      transcript names, else 200000.
#   2. The per-window rung-flag helpers — one flag file per hook, per session,
#      in a stable state dir (persisted across invocations, unlike a mktemp).
#   3. The capacity-driven reset — there is no session-start hook anymore, so
#      a new window is detected by CAPACITY: when measured fill drops well
#      below the last-seen fill (a compaction, or a fresh session reusing an
#      id), the per-window flags are cleared so read-product-context and
#      read-memory fire again and append-memory re-climbs. Last-seen fill is
#      persisted per session id in the state dir.
#   4. The deadline — each measurement self-bounds with SIGALRM
#      (SPEQQ_HOOK_TIMEOUT_SECONDS, default 5s), so a pathological transcript
#      can never hang a tool call.
#
# Invariants every path upholds:
#   - NEVER BLOCK A TOOL CALL. Every path exits 0.
#   - STDOUT IS SACRED. Only the intentional context-injection JSON goes
#     there; a hook that does not fire prints nothing.
#   - STDERR IS DIAGNOSTICS. A real runtime failure prints exactly ONE line
#     naming the cause, and still exits 0.
#   - TOKENLESS. No network, no credentials, no MCP, no curl. The hooks only
#     measure the local transcript and print instructions for the agent to
#     act on over its OWN MCP connection.
#
# Requires: python3 (each hook checks before use).

case ${0##*/} in
lib.sh)
  printf 'speqq hooks: lib.sh is a library - it is sourced by the hooks, not run\n' >&2
  exit 0
  ;;
esac

# ---------------------------------------------------------------------------
# The engine. One python pass shared by the three capacity-driven hooks.
#
# argv:
#   1 mode          "read" | "ladder"
#   2 flag          this hook's per-window flag basename
#                   ("read-product" | "read-memory" | "append-ladder")
#   3 param         read: the near-empty threshold percent
#                   ladder: a comma list of rung percents
#   4 template      instruction text to inject when the rung fires; the engine
#                   substitutes {pct} (rounded fill) and {session}
#   5 template_final ladder only: the text for the top rung (may be empty)
#
# Env:
#   SPEQQ_CONTEXT_WINDOW          override the denominator (tokens)
#   SPEQQ_CONTEXT_RESET_DROP      percent drop that means a new window (def 20)
#   SPEQQ_HOOK_TIMEOUT_SECONDS    self-timeout for the measurement (def 5)
#   SPEQQ_HOOK_STATE_DIR          where flags live (def system temp dir)
#
# Stdout: the injection JSON on a fire, nothing otherwise.
# Double quotes only inside — the whole thing is single-quoted shell.
# ---------------------------------------------------------------------------
SPEQQ_ENGINE_PY='
import json
import os
import re
import signal
import sys
import tempfile

DEFAULT_WINDOW = 200000
TAIL_BYTES = 262144
# Every per-window flag the capacity reset clears. Kept here, in one place, so
# any of the three hooks that runs first on a new window re-arms all of them.
PER_WINDOW_FLAGS = ("read-product", "read-memory", "append-ladder")


def diag(message):
    sys.stderr.write("speqq hooks: " + str(message).replace("\n", " ") + "\n")


def state_dir():
    override = os.environ.get("SPEQQ_HOOK_STATE_DIR", "").strip()
    return override if override else tempfile.gettempdir()


def flag_path(name, session):
    return os.path.join(state_dir(), "speqq-" + name + "-" + session)


def env_float(name, default):
    raw = os.environ.get(name, "").strip()
    try:
        return float(raw)
    except ValueError:
        return default


def env_window():
    raw = os.environ.get("SPEQQ_CONTEXT_WINDOW", "").strip()
    return int(raw) if raw.isdigit() and int(raw) > 0 else 0


def usage_from_claude(entry):
    """Claude Code JSONL: the assistant record carries message.usage; the
    window fill is the last request prompt (fresh + cache writes + cache
    reads)."""
    if entry.get("type") != "assistant":
        return None
    message = entry.get("message")
    usage = message.get("usage") if isinstance(message, dict) else None
    if not isinstance(usage, dict):
        return None
    used = (
        int(usage.get("input_tokens", 0) or 0)
        + int(usage.get("cache_creation_input_tokens", 0) or 0)
        + int(usage.get("cache_read_input_tokens", 0) or 0)
    )
    return (used, 0)


def usage_from_codex(entry):
    """Codex rollout: event_msg records with payload.type token_count carry
    info.last_token_usage (the last request, prompt side already inclusive of
    cached tokens) and info.model_context_window (the window itself)."""
    payload = entry.get("payload")
    if not isinstance(payload, dict) or payload.get("type") != "token_count":
        return None
    info = payload.get("info")
    if not isinstance(info, dict):
        return None
    last = info.get("last_token_usage")
    if not isinstance(last, dict):
        return None
    used = int(last.get("input_tokens", 0) or 0)
    if used <= 0:
        return None
    window = info.get("model_context_window")
    window = int(window) if isinstance(window, (int, float)) and int(window) > 0 else 0
    return (used, window)


def measure(transcript):
    """The LAST record carrying usage tells the current window fill. Tail only:
    long transcripts are huge and this runs after every tool call."""
    with open(transcript, "rb") as handle:
        handle.seek(0, 2)
        handle.seek(max(0, handle.tell() - TAIL_BYTES))
        lines = handle.read().decode("utf-8", "replace").splitlines()
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if not isinstance(entry, dict):
            continue
        hit = usage_from_claude(entry) or usage_from_codex(entry)
        if hit:
            return hit
    return None


def read_flag(name, session):
    try:
        with open(flag_path(name, session)) as handle:
            return handle.read().strip()
    except (OSError, ValueError):
        return ""


def write_flag(name, session, value):
    try:
        with open(flag_path(name, session), "w") as handle:
            handle.write(value)
    except OSError as error:
        diag("could not write the " + name + " flag: " + str(error))


def clear_window_flags(session):
    for name in PER_WINDOW_FLAGS:
        try:
            os.remove(flag_path(name, session))
        except OSError:
            pass


def reset_on_new_window(session, pct):
    """No session-start hook exists to re-arm the ladder, so capacity does it:
    a fill well below the last-seen fill is a compaction or a fresh session,
    and clears the per-window flags. Last-seen fill is persisted per session."""
    drop = env_float("SPEQQ_CONTEXT_RESET_DROP", 20.0)
    last_raw = read_flag("lastfill", session)
    try:
        last = float(last_raw)
    except ValueError:
        last = None
    if last is not None and pct < last - drop:
        clear_window_flags(session)
    write_flag("lastfill", session, "%.2f" % pct)


def emit(template, template_final, final, pct, session):
    text = (template_final if final and template_final else template)
    text = text.replace("{pct}", "%d" % round(pct)).replace("{session}", session)
    sys.stdout.write(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": text,
                }
            }
        )
    )


def run():
    signal.alarm(int(env_float("SPEQQ_HOOK_TIMEOUT_SECONDS", 5.0)) or 5)

    mode = sys.argv[1]
    flag = sys.argv[2]
    param = sys.argv[3]
    template = sys.argv[4] if len(sys.argv) > 4 else ""
    template_final = sys.argv[5] if len(sys.argv) > 5 else ""

    raw = "" if sys.stdin.isatty() else sys.stdin.read()
    try:
        payload = json.loads(raw)
    except ValueError:
        raise SystemExit(0)
    if not isinstance(payload, dict):
        raise SystemExit(0)

    session = payload.get("session_id", "")
    transcript = payload.get("transcript_path", "")
    if not isinstance(session, str) or not re.fullmatch(r"[A-Za-z0-9._-]{1,128}", session):
        raise SystemExit(0)
    if not isinstance(transcript, str) or not os.path.isfile(transcript):
        raise SystemExit(0)

    hit = measure(transcript)
    if hit is None:
        raise SystemExit(0)
    used, record_window = hit
    explicit = env_window()
    window = explicit or record_window or DEFAULT_WINDOW
    pct = used * 100.0 / window

    # Re-arm the ladder by capacity BEFORE gating, so a hook that fires this
    # same window sees its freshly cleared flag.
    reset_on_new_window(session, pct)

    if mode == "read":
        if read_flag(flag, session):
            raise SystemExit(0)
        try:
            threshold = float(param)
        except ValueError:
            raise SystemExit(0)
        if pct >= threshold:
            raise SystemExit(0)
        write_flag(flag, session, "1")
        emit(template, "", False, pct, session)
        return

    if mode == "ladder":
        rungs = sorted(float(p) for p in param.split(",") if p.strip())
        if not rungs:
            raise SystemExit(0)
        fired_raw = read_flag(flag, session)
        try:
            fired = float(fired_raw) if fired_raw else -1.0
        except ValueError:
            fired = -1.0
        due = [r for r in rungs if r > fired and pct >= r]
        if not due:
            raise SystemExit(0)
        if pct > 100 and not (explicit or record_window):
            # A fill above 100% against the assumed default proves the default
            # window wrong for this model (Claude transcripts never name
            # theirs). Guessing a bigger window would guess the rungs too —
            # park the ladder for this window and say so once; the flag keeps
            # the line from repeating on every tool call.
            write_flag(flag, session, "%.1f" % max(rungs))
            diag(
                "measured %d tokens against the assumed %d-token window - set "
                "SPEQQ_CONTEXT_WINDOW to the real model window; the append ladder "
                "is parked for this window" % (used, window)
            )
            raise SystemExit(0)
        rung = max(due)
        final = rung == max(rungs)
        # Record the rung BEFORE emitting, so a crash after this line costs one
        # nudge, never a nudge storm.
        write_flag(flag, session, "%.1f" % rung)
        emit(template, template_final, final, pct, session)
        return

    diag("unknown engine mode: " + mode)


def _alarm(signum, frame):
    raise SystemExit(0)


try:
    signal.signal(signal.SIGALRM, _alarm)
    run()
except SystemExit:
    raise
except Exception as error:  # noqa: BLE001 - one diagnostic line, never blocks
    diag(error)
    raise SystemExit(0)
'

# ---------------------------------------------------------------------------
# The one shell entry point each capacity-driven hook calls last. It runs the
# engine with the hook's mode/flag/param and instruction text, then exits 0 no
# matter what — the engine already printed any injection to stdout and any
# diagnostic to stderr.
# ---------------------------------------------------------------------------
speqq_run() {
  command -v python3 >/dev/null 2>&1 || exit 0
  python3 -c "$SPEQQ_ENGINE_PY" "$@" || :
  exit 0
}
