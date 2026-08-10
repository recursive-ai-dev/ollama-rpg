# ═══════════════════════════════════════════════════════════════════════════
# lib/tui.sh — terminal control and HUD rendering
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_TUI:-}" ]] && return
declare -g _OLlama_RPG_TUI=1

update_term_size() {
  TERM_W=$(tput cols 2>/dev/null || stty size 2>/dev/null | awk '{print $2}' || echo 80)
  TERM_H=$(tput lines 2>/dev/null || stty size 2>/dev/null | awk '{print $1}' || echo 24)
  [[ -z "$TERM_W" || "$TERM_W" -lt 60 ]] && TERM_W=80
  [[ -z "$TERM_H" || "$TERM_H" -lt 20 ]] && TERM_H=24
}

clear_screen() {
  printf '%s%s' "$CLEAR" "$HOME_C"
}

# Draw a horizontal rule with optional centered title.
# Uses bash string repetition (not tr) for proper multi-byte Unicode support.
hr() {
  local title="${1:-}"
  local width=${2:-$TERM_W}
  local char="${3:-─}"

  _repeat_char() {
    local n=$1 c=$2 out=""
    local i
    for ((i=0; i<n; i++)); do out+="$c"; done
    printf '%s' "$out"
  }

  if [[ -n "$title" ]]; then
    local title_len=${#title}
    local pad=$(( (width - title_len - 2) / 2 ))
    [[ $pad -lt 1 ]] && pad=1
    local right_pad=$(( width - pad - title_len - 2 ))
    [[ $right_pad -lt 0 ]] && right_pad=0
    printf '%s' "${P_DIM_GREEN}"
    _repeat_char "$pad" "$char"
    printf '%s %s%s%s %s' "$RESET" "$P_GOLD" "$title" "$RESET" "${P_DIM_GREEN}"
    _repeat_char "$right_pad" "$char"
    printf '%s\n' "$RESET"
  else
    printf '%s' "${P_DIM_GREEN}"
    _repeat_char "$width" "$char"
    printf '%s\n' "$RESET"
  fi
}

# Word-wrap text to width, print each line (with optional indent).
wrap_print() {
  local text="$1" width="${2:-$((TERM_W - 4))}"
  local indent="${3:-0}"
  local indent_str=""
  [[ $indent -gt 0 ]] && indent_str=$(printf '%*s' "$indent" '')
  printf '%s' "$text" | fold -s -w "$width" | while IFS= read -r ln; do
    printf '%s%s%s\n' "$indent_str" "$ln" "$RESET"
  done
}

# Build a filled/empty progress bar. Args: current, max, width.
progress_bar() {
  local cur=$1 max=$2 width=${3:-20}
  local pct=0
  if (( max > 0 )); then
    pct=$(( cur * 100 / max ))
  fi
  local filled=$(( width * pct / 100 ))
  [[ $filled -gt $width ]] && filled=$width
  local empty=$(( width - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf '%s' "$bar"
}

# Draw a boxed banner used by encounters/achievements.
# Args: color_code title_line (remaining lines printed inside box)
box_banner() {
  local color="$1"; shift
  local title="$1"; shift
  local width=$TERM_W
  local inner=$(( width - 4 ))
  printf '%s%s╔%s╗%s\n' "$color" "$RESET" "$(printf '%*s' "$inner" '' | tr ' ' '═')" "$RESET"
  printf '%s%s║%s %-*s%s║%s\n' "$color" "$RESET" "$P_GOLD" "$inner" "$title" "$color" "$RESET"
  for line in "$@"; do
    printf '%s%s║%s %-*s%s║%s\n' "$color" "$RESET" "$P_GREEN" "$inner" "$line" "$color" "$RESET"
  done
  printf '%s%s╚%s╝%s\n' "$color" "$RESET" "$(printf '%*s' "$inner" '' | tr ' ' '═')" "$RESET"
}

# ─────────────────────────────────────────────────────────────────────────────
# HEADER / STATUS BAR
# ─────────────────────────────────────────────────────────────────────────────

render_header() {
  local lvl=${CHAR[level]}
  local title
  title=$(class_title "$lvl")
  local xp_needed
  xp_needed=$(xp_for_level "$lvl")

  echo ""
  printf '  %s%s⚔  OLLAMA RPG  ⚔%s  %sLv.%s %s%s%s\n' \
    "$B_GOLD" "$BOLD" "$RESET" \
    "$P_AMBER" "$lvl" "$P_GREEN" "$title" "$RESET"

  printf '  %sXP%s %s[%s]%s %s%s/%s%s%s\n' \
    "$P_AMBER" "$RESET" \
    "$P_GREEN" "$(progress_bar "${CHAR[xp]}" "$xp_needed" 16)" "$RESET" \
    "$P_GOLD" "${CHAR[xp]}" "$P_GREY" "$xp_needed" "$RESET"

  printf '  %sHP%s %s[%s]%s %s%d/%d%s   %sMP%s %s[%s]%s %s%d/%d%s   %s◈ %sGold: %s%d%s\n' \
    "$P_RED"  "$RESET" "$P_RED"  "$(progress_bar "${CHAR[hp]}" "${CHAR[hp_max]}" 10)" "$RESET" "$P_RED"  "${CHAR[hp]}"  "${CHAR[hp_max]}"  "$RESET" \
    "$P_CYAN" "$RESET" "$P_CYAN" "$(progress_bar "${CHAR[mp]}" "${CHAR[mp_max]}" 10)" "$RESET" "$P_CYAN" "${CHAR[mp]}" "${CHAR[mp_max]}" "$RESET" \
    "$P_GOLD" "$RESET" "$P_GOLD" "${CHAR[gold]}" "$RESET"

  # Model + persona + streak
  local persona_name="Default"
  if [[ "${CHAR[persona]}" != "default" ]]; then
    persona_name=$(skill_field "${CHAR[persona]}" name 2>/dev/null || echo "${CHAR[persona]}")
  fi
  local sys_name="Base"
  if [[ "${CHAR[system_prompt]}" != "base" ]]; then
    sys_name=$(skill_field "${CHAR[system_prompt]}" name 2>/dev/null || echo "${CHAR[system_prompt]}")
  fi

  printf '  %sModel:%s %s%s%s   %sPersona:%s %s%s%s   %sStreak:%s %s%d🔥%s\n' \
    "$P_AMBER" "$RESET" "$P_GREEN" "${CHAR[model]:-none}" "$RESET" \
    "$P_AMBER" "$RESET" "$P_GREEN" "$persona_name" "$RESET" \
    "$P_AMBER" "$RESET" "$P_GOLD" "${CHAR[streak]}" "$RESET"

  hr "Conclave" "$TERM_W"
}

render_conversation() {
  local count=${#MSG_ROLE[@]}
  if (( count == 0 )); then
    printf '\n  %s%sThe conclave is silent. Speak, apprentice.%s\n' "$ITALIC" "$P_GREY" "$RESET"
    printf '\n  %sAsk a question, share code, or type /help for commands.%s\n' "$P_DIM_GREEN" "$RESET"
    return
  fi

  local start=0
  if (( count > 8 )); then
    start=$(( count - 8 ))
  fi

  for ((i=start; i<count; i++)); do
    local role="${MSG_ROLE[i]}"
    local text="${MSG_TEXT[i]}"

    if [[ "$role" == "user" ]]; then
      printf '  %s▶ You:%s ' "$B_AMBER" "$RESET"
      wrap_print "$text" "$((TERM_W - 8))" 0 | sed "s/^/  /"
    elif [[ "$role" == "assistant" ]]; then
      printf '  %s✦ Wizard:%s ' "$B_GREEN" "$RESET"
      wrap_print "$text" "$((TERM_W - 8))" 0 | sed "s/^/  /"
    fi
    echo ""
  done
}

render_footer() {
  hr "" "$TERM_W"
  # Active skills summary
  local active_names=""
  if [[ -n "${CHAR[active_skills]:-}" ]]; then
    local IFS=','
    read -ra ids <<< "${CHAR[active_skills]}"
    unset IFS
    for id in "${ids[@]}"; do
      [[ -z "$id" ]] && continue
      local name
      name=$(skill_field "$id" name 2>/dev/null) || continue
      if [[ -n "$active_names" ]]; then
        active_names+=", $name"
      else
        active_names="$name"
      fi
    done
  fi
  if [[ -z "$active_names" ]]; then
    active_names="${P_GREY}none${RESET}"
  fi
  printf '  %sActive Skills:%s %s\n' "$P_AMBER" "$RESET" "$active_names"

  hr "" "$TERM_W"
  printf '  %s%s/help%s %sskills%s %stalents%s %smodel%s %spersona%s %squest%s %sstatus%s %sinv%s %sach%s %squit%s\n' \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET" \
    "$P_DIM_GREEN" "$RESET"
  hr "" "$TERM_W"
}
