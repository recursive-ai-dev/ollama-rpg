# ═══════════════════════════════════════════════════════════════════════════
# lib/main.sh — boot sequence, main loop, streak, cleanup
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_MAIN:-}" ]] && return
declare -g _OLlama_RPG_MAIN=1

# ─────────────────────────────────────────────────────────────────────────────
# STREAK / DAILY LOGIN
# ─────────────────────────────────────────────────────────────────────────────

update_streak() {
  local today
  today=$(date '+%Y-%m-%d')
  local last="${CHAR[last_login]:-}"

  if [[ -z "$last" ]]; then
    CHAR[streak]=1
  elif [[ "$last" == "$today" ]]; then
    :
  else
    local yesterday
    yesterday=$(date -d 'yesterday' '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d' 2>/dev/null)
    if [[ "$last" == "$yesterday" ]]; then
      CHAR[streak]=$(( ${CHAR[streak]} + 1 ))
      local bonus=${CHAR[streak]}
      if has_talent "time_lord"; then bonus=$(( bonus * 2 )); fi
      local streak_xp=$(( bonus * 5 ))
      echo ""
      printf '  %s%s🔥 Daily streak: %d days! +%d XP bonus.%s\n' \
        "$B_GOLD" "$BOLD" "${CHAR[streak]}" "$streak_xp" "$RESET"
      CHAR[xp]=$(( ${CHAR[xp]} + streak_xp ))
    else
      CHAR[streak]=1
    fi
  fi

  CHAR[last_login]="$today"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────────────────────────────────────

main_loop() {
  # Load persistent prompt history so ↑/↓ recall previous prompts.
  history -r "$PROMPT_HIST_FILE" 2>/dev/null || true

  while true; do
    update_term_size
    clear_screen
    render_header
    render_conversation
    render_footer

    printf '\n  %s> %s' "$B_GREEN" "$RESET"

    local user_input
    if ! read -e -r user_input; then
      # EOF (Ctrl+D) or read error — treat as quit instead of spinning.
      auto_save_session
      printf '\n  %sFarewell, apprentice.%s\n' "$P_AMBER" "$RESET"
      break
    fi
    # Persist the prompt for next session (skip empty lines)
    if [[ -n "$user_input" ]]; then
      history -s "$user_input"
      history -w "$PROMPT_HIST_FILE" 2>/dev/null || true
    fi

    # Slash command?
    if [[ "$user_input" =~ ^/ ]]; then
      handle_command "$user_input"
      continue
    fi

    # Empty input — just re-render
    [[ -z "$user_input" ]] && continue

    # Add user message to log
    MSG_ROLE+=("user")
    MSG_TEXT+=("$user_input")

    if (( ${#MSG_ROLE[@]} > MAX_LOG_MESSAGES )); then
      MSG_ROLE=("${MSG_ROLE[@]:1}")
      MSG_TEXT=("${MSG_TEXT[@]:1}")
    fi

    # Build full prompt with prefixes
    local prefix system full_prompt
    prefix=$(compute_prompt_prefix)
    system=$(compute_system_prompt)
    if [[ -n "$prefix" ]]; then
      full_prompt="${prefix}

${user_input}"
    else
      full_prompt="$user_input"
    fi

    # Show "thinking" indicator
    clear_screen
    render_header
    render_conversation
    render_footer
    printf '\n  %s> %s%s%s\n' "$B_GREEN" "$user_input" "$RESET" "$P_GREY"
    printf '\n  %s✦ Wizard:%s ' "$B_GREEN" "$RESET"
    printf '%s(thinking...)%s' "$P_DIM_GREEN" "$RESET"
    printf '\r  %s✦ Wizard:%s ' "$B_GREEN" "$RESET"

    if ! ollama_check; then
      printf '%s✗ Cannot reach Ollama at %s%s\n' "$P_RED" "$OLLAMA_URL" "$RESET"
      printf '  %sStart it with: ollama serve%s\n' "$P_AMBER" "$RESET"
      MSG_ROLE+=("assistant")
      MSG_TEXT+=("[Error: Ollama unreachable at $OLLAMA_URL]")
      sleep 2
      continue
    fi

    ollama_chat "${CHAR[model]}" "$system" "$full_prompt"

    # Add assistant response to log
    MSG_ROLE+=("assistant")
    MSG_TEXT+=("$LAST_RESPONSE")

    if (( ${#MSG_ROLE[@]} > MAX_LOG_MESSAGES )); then
      MSG_ROLE=("${MSG_ROLE[@]:1}")
      MSG_TEXT=("${MSG_TEXT[@]:1}")
    fi

    # Award XP: base per prompt + per token
    local xp_gain=$XP_PER_PROMPT
    local token_xp=$(( LAST_TOKENS / TOKEN_XP_DIVISOR ))
    xp_gain=$(( xp_gain + token_xp ))

    if has_talent "deep_thinker"; then
      xp_gain=$(( xp_gain + token_xp / 2 ))
    fi
    if has_talent "polyglot"; then
      xp_gain=$(( xp_gain + 1 ))
    fi

    printf '\n\n  %s%s+%d XP%s %s(prompt: %d, tokens: %d)%s\n' \
      "$B_GOLD" "$BOLD" "$xp_gain" "$RESET" "$P_GREY" "$XP_PER_PROMPT" "$token_xp" "$RESET"

    CHAR[prompts_sent]=$(( ${CHAR[prompts_sent]} + 1 ))
    CHAR[tokens_received]=$(( ${CHAR[tokens_received]} + LAST_TOKENS ))

    apply_xp "$xp_gain"

    # Natural Healer: regenerate HP after each prompt
    local regen
    regen=$(talent_regen_hp)
    if (( regen > 0 )) && (( ${CHAR[hp]} < ${CHAR[hp_max]} )); then
      CHAR[hp]=$(( ${CHAR[hp]} + regen ))
      (( ${CHAR[hp]} > ${CHAR[hp_max]} )) && CHAR[hp]=${CHAR[hp_max]}
      printf '  %s%s+%d HP (Natural Healer)%s\n' "$P_GREEN" "$BOLD" "$regen" "$RESET"
    fi

    # Random world encounter
    maybe_encounter

    printf '\n  %s(press any key to continue)%s' "$P_DIM_GREEN" "$RESET"
    read -n 1 -s -r
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# CLEANUP
# ─────────────────────────────────────────────────────────────────────────────

cleanup() {
  # Skip in subshells: `trap cleanup EXIT` fires when every pipeline subshell
  # ends, which would spray cursor escapes into the middle of the stream.
  [[ "${BASH_SUBSHELL:-0}" -eq 0 ]] || return 0
  printf '%s' "$SHOW_CURSOR"
  printf '%s' "$RESET"
  if [[ -n "${_IN_ALT_SCREEN:-}" ]]; then
    printf '%s' "$RMCUP"
  fi
  stty sane 2>/dev/null || true
}

# INT/TERM: restore the terminal and actually terminate — before this, the
# trap only cleaned up and the game kept spinning on blocked reads.
_term_handler() {
  [[ "${BASH_SUBSHELL:-0}" -eq 0 ]] || return 0
  cleanup
  exit 0
}

trap cleanup EXIT
trap _term_handler INT TERM

# ─────────────────────────────────────────────────────────────────────────────
# BOOT
# ─────────────────────────────────────────────────────────────────────────────

rpg_boot() {
  update_term_size

  # Enter the alternate screen buffer so the game plays on a clean
  # fullscreen surface and the terminal scrollback is restored on exit.
  if [[ -t 1 ]]; then
    printf '%s' "$SMCUP"
    declare -g _IN_ALT_SCREEN=1
  fi
  printf '%s' "$HIDE_CURSOR"

  splash_screen

  if load_state; then
    printf '  %s✓ Save loaded.%s\n' "$P_GREEN" "$RESET"
    [[ -z "${CHAR[created]}" ]] && CHAR[created]=$(date '+%Y-%m-%d %H:%M:%S')
  else
    printf '  %s✦ No save found. A new apprentice is born.%s\n' "$P_AMBER" "$RESET"
    CHAR[created]=$(date '+%Y-%m-%d %H:%M:%S')
    CHAR[streak]=1
    CHAR[gold]=$STARTING_GOLD
    grant_achievement "acolyte"
  fi

  if ollama_check; then
    printf '  %s✓ Ollama reachable at %s%s\n' "$P_GREEN" "$OLLAMA_URL" "$RESET"
  else
    printf '  %s✗ Ollama not reachable at %s%s\n' "$P_RED" "$OLLAMA_URL" "$RESET"
    printf '  %s  Start it with: ollama serve%s\n' "$P_AMBER" "$RESET"
    printf '  %s  You can browse menus but chat will fail.%s\n\n' "$P_GREY" "$RESET"
  fi

  if [[ -z "${CHAR[model]}" ]]; then
    printf '\n  %sNo familiar bound. Choose one to begin.%s\n' "$P_AMBER" "$RESET"
    model_picker || true
  fi

  # A model passed on the command line wins over any stale saved model.
  if [[ -n "${OLLAMA_RPG_CLI_MODEL:-}" ]]; then
    CHAR[model]="$OLLAMA_RPG_CLI_MODEL"
  fi

  update_streak
  check_achievements
  save_state

  printf '\n  %s%s⚔  Welcome, apprentice. Type /help for commands.  ⚔%s\n\n' "$B_GOLD" "$BOLD" "$RESET"
  read -n 1 -s -r -p "  Press any key to enter the conclave..."

  main_loop
}
