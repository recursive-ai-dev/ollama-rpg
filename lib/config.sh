# ═══════════════════════════════════════════════════════════════════════════
# lib/config.sh — configuration constants and runtime paths
# ═══════════════════════════════════════════════════════════════════════════
#
# Sourced by the main launcher. Defines API/endpoint config, save paths,
# tunable limits and the global script version. The ANSI palette lives in
# the companion lib/palette.sh.

[[ -n "${_OLlama_RPG_CONFIG:-}" ]] && return
declare -g _OLlama_RPG_CONFIG=1

# ── Runtime configuration ───────────────────────────────────────────────────
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
SAVE_FILE="${SAVE_FILE:-${HOME}/.ollama-rpg-save}"
SCRIPT_VERSION="2.0.0"
MAX_LOG_MESSAGES=50            # keep last N messages in memory
LOG_FILE="${LOG_FILE:-${HOME}/.ollama-rpg.log}"

# Derived data directories
SNIPPET_DIR="${HOME}/.ollama-rpg-snippets"
SESSION_DIR="${HOME}/.ollama-rpg-sessions"

# Tunable progression knobs (override via env if you like)
XP_PER_PROMPT="${XP_PER_PROMPT:-5}"
TOKEN_XP_DIVISOR="${TOKEN_XP_DIVISOR:-10}"
ENCOUNTER_CHANCE="${ENCOUNTER_CHANCE:-12}"     # percent chance per prompt
STARTING_GOLD="${STARTING_GOLD:-0}"

# Ensure derived directories exist (snippets/sessions created lazily too)
mkdir -p "$SNIPPET_DIR" "$SESSION_DIR" 2>/dev/null || true
