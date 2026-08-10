#!/usr/bin/env bash
#
#  ╔══════════════════════════════════════════════════════════════════════╗
#  ║                                                                      ║
#  ║   O L L A M A   R P G   —   a Fantasy Coding RPG for the Terminal   ║
#  ║                                                                      ║
#  ║   Bash only • No dependencies • Runs locally • Saves locally        ║
#  ║                                                                      ║
#  ║   Gain XP by conversing with your AI mentor. Level up to unlock     ║
#  ║   skills, talents, personas, system prompts — and now items,         ║
#  ║   achievements, random encounters and a living world codex.          ║
#  ║                                                                      ║
#  ║   Requires: bash 4+, curl, standard unix utils (sed, awk, grep)     ║
#  ║   Save file: ~/.ollama-rpg-save                                     ║
#  ║                                                                      ║
#  ╚══════════════════════════════════════════════════════════════════════╝
#
#  Usage:
#    ./ollama-rpg.sh                # normal launch
#    OLLAMA_URL=http://host:11434 ./ollama-rpg.sh
#    ./ollama-rpg.sh --reset        # wipe save and start over
#    ./ollama-rpg.sh --help
#
#  This file is a thin launcher. All logic lives in lib/*.sh which are
#  sourced in dependency order below.
#

set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# LOCATE LIBRARIES
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${LIB_DIR:-$SCRIPT_DIR/lib}"

if [[ ! -d "$LIB_DIR" ]]; then
  echo "Error: library directory not found: $LIB_DIR" >&2
  exit 1
fi

# Source everything in dependency order. Each lib file self-guards against
# being sourced more than once.
for lib in config palette state data ollama effects progression tui screens tools encounters lore commands main; do
  lib_path="$LIB_DIR/${lib}.sh"
  if [[ ! -f "$lib_path" ]]; then
    echo "Error: missing library: $lib_path" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$lib_path"
done

# ─────────────────────────────────────────────────────────────────────────────
# ARGUMENTS / INITIALIZATION
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
  cat <<EOF
Ollama RPG v$SCRIPT_VERSION — A Fantasy Coding RPG for the Terminal

Usage:
  ./ollama-rpg.sh              Start the game (loads or creates save)
  ./ollama-rpg.sh --reset      Wipe save and start a new character
  ./ollama-rpg.sh --help       Show this help
  ./ollama-rpg.sh <model>      Start with a specific Ollama model bound

Environment:
  OLLAMA_URL                   Ollama endpoint (default: http://localhost:11434)
  SAVE_FILE                    Save path (default: ~/.ollama-rpg-save)
  LIB_DIR                      Override path to the lib/ directory

Files:
  ~/.ollama-rpg-save           Character save file (key=value format)
  ~/.ollama-rpg-snippets/      Saved code snippets
  ~/.ollama-rpg-sessions/      Saved conversation sessions

Requires:
  bash 4+, curl, sed, awk, grep  (all standard on modern Unix)
  Ollama running locally (or at \$OLLAMA_URL)

In-game commands: type /help for the full codex.
EOF
}

# Only run when executed directly (not sourced by external tooling).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

case "${1:-}" in
  --help|-h) show_help; exit 0 ;;
  --reset)
    if [[ -f "$SAVE_FILE" ]]; then
      read -r -p "Erase save file and start over? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy] ]]; then
        rm -f "$SAVE_FILE"
        printf 'Save erased.\n'
      else
        printf 'Aborted.\n'
        exit 0
      fi
    fi
    ;;
  "") ;;
  *)
    CHAR[model]="$1"
    ;;
esac

# Boot the game (defined in lib/main.sh)
rpg_boot

fi  # end BASH_SOURCE guard
