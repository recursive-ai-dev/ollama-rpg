# ═══════════════════════════════════════════════════════════════════════════
# lib/palette.sh — ANSI escape codes, the Phosphor Fantasy palette
# ═══════════════════════════════════════════════════════════════════════════
#
# Black background, phosphor green primary, amber/gold for emphasis.
# Cursor and screen control sequences are included for the TUI.

[[ -n "${_OLlama_RPG_PALETTE:-}" ]] && return
declare -g _OLlama_RPG_PALETTE=1

ESC=$'\033'
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
ITALIC="${ESC}[3m"
UNDERLINE="${ESC}[4m"
BLINK="${ESC}[5m"
REVERSE="${ESC}[7m"

# Phosphor palette
P_GREEN="${ESC}[38;5;46m"        # bright phosphor green
P_DIM_GREEN="${ESC}[38;5;22m"    # dark forest green
P_MID_GREEN="${ESC}[38;5;34m"    # medium green
P_AMBER="${ESC}[38;5;214m"       # amber
P_GOLD="${ESC}[38;5;220m"        # bright gold
P_RED="${ESC}[38;5;196m"         # alert red
P_BLUE="${ESC}[38;5;33m"         # magic blue
P_CYAN="${ESC}[38;5;51m"         # mystic cyan
P_GREY="${ESC}[38;5;240m"        # muted grey
P_WHITE="${ESC}[38;5;255m"       # near-white
P_PURPLE="${ESC}[38;5;141m"      # arcane purple (new)
P_PINK="${ESC}[38;5;205m"        # encounter pink (new)

# Bold variants
B_GREEN="${ESC}[1;38;5;46m"
B_AMBER="${ESC}[1;38;5;214m"
B_GOLD="${ESC}[1;38;5;220m"
B_RED="${ESC}[1;38;5;196m"
B_CYAN="${ESC}[1;38;5;51m"
B_WHITE="${ESC}[1;38;5;255m"
B_PURPLE="${ESC}[1;38;5;141m"
B_PINK="${ESC}[1;38;5;205m"

# Cursor / screen control
HIDE_CURSOR="${ESC}[?25l"
SHOW_CURSOR="${ESC}[?25h"
CLEAR="${ESC}[2J"
HOME_C="${ESC}[H"
CLEAR_LINE="${ESC}[2K"
SAVE_C="${ESC}7"
LOAD_C="${ESC}8"

# Alternate screen buffer (only entered when stdout is a tty; harmless no-op
# sequences otherwise). Let `tput` decide, fall back to the xterm sequence.
SMCUP="$(tput smcup 2>/dev/null || printf '\033[?1049h')"
RMCUP="$(tput rmcup 2>/dev/null || printf '\033[?1049l')"
