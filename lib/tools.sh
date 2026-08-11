# ═══════════════════════════════════════════════════════════════════════════
# lib/tools.sh — shell utility tools and loot rolling
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_TOOLS:-}" ]] && return
declare -g _OLlama_RPG_TOOLS=1

# Roll a weighted random item from ITEM_DROPS. Echoes the item id.
roll_item_drop() {
  local total=0 id weight
  for drop in "${ITEM_DROPS[@]}"; do
    weight=${drop##*|}
    total=$(( total + weight ))
  done
  local roll=$(( RANDOM % total ))
  local accum=0
  for drop in "${ITEM_DROPS[@]}"; do
    id=${drop%%|*}
    weight=${drop##*|}
    accum=$(( accum + weight ))
    if (( roll < accum )); then
      echo "$id"
      return
    fi
  done
  # Fallback (should not happen)
  echo "${ITEM_DROPS[0]%%:*}"
}

run_shell_tool() {
  local tool_id=$1

  if [[ ",${CHAR[skills]}," != *",$tool_id,"* ]]; then
    printf '  %sTool not unlocked.%s\n' "$P_RED" "$RESET"
    sleep 1
    return
  fi

  local tool_name
  tool_name=$(skill_field "$tool_id" name)

  case $tool_id in
    snippet)    _tool_snippets ;;
    file)       _tool_file_browser ;;
    history)    _tool_history ;;
    diff)       _tool_diff_viewer ;;
    clear)      _tool_clear_log ;;
    save)       _tool_save_session ;;
    man)        _tool_man ;;
    git)        _tool_git ;;
    search)     _tool_search ;;
    spell)      _tool_spell ;;
    *)
      printf '  %sUnknown tool: %s%s\n' "$P_RED" "$tool_id" "$RESET"
      sleep 1
      ;;
  esac
}

_tool_clear_log() {
  MSG_ROLE=()
  MSG_TEXT=()
  printf '  %sConversation log cleared.%s\n' "$P_GREEN" "$RESET"
  sleep 1
}

_tool_snippets() {
  clear_screen
  printf '\n  %s%sSnippet Grimoire%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  if [[ ! -d "$SNIPPET_DIR" || -z "$(ls -A "$SNIPPET_DIR" 2>/dev/null)" ]]; then
    printf '  %sNo snippets saved. Use /snippet save <name> to create one.%s\n' "$P_GREY" "$RESET"
  else
    printf '  %sSaved snippets:%s\n' "$P_AMBER" "$RESET"
    local idx=1
    for f in "$SNIPPET_DIR"/*; do
      [[ -f "$f" ]] || continue
      printf '  %s[%d]%s %s%s%s\n' "$P_GOLD" "$idx" "$RESET" "$P_GREEN" "$(basename "$f")" "$RESET"
      ((idx++))
    done
  fi
  hr "" "$TERM_W"
  read -n 1 -s -r -p "  Press any key to return..."
}

_tool_file_browser() {
  clear_screen
  printf '\n  %s%sTome Browser%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  printf '  %sEnter a file path to view:%s ' "$P_GREEN" "$RESET"
  local path
  read -r path
  if [[ -z "$path" || ! -f "$path" ]]; then
    printf '  %sFile not found.%s\n' "$P_RED" "$RESET"
    sleep 1
    return
  fi
  clear_screen
  printf '  %s%s━━ %s ━━%s\n\n' "$B_GOLD" "$BOLD" "$path" "$RESET"
  head -100 "$path" | while IFS= read -r line; do
    printf '  %s%s%s\n' "$P_GREEN" "$line" "$RESET"
  done
  local total
  total=$(wc -l < "$path")
  if (( total > 100 )); then
    printf '\n  %s... (%d more lines)%s\n' "$P_GREY" "$((total - 100))" "$RESET"
  fi
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}

_tool_history() {
  clear_screen
  printf '\n  %s%sMemory Crystal — Conversation History%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  if (( ${#MSG_ROLE[@]} == 0 )); then
    printf '  %sNo history yet.%s\n' "$P_GREY" "$RESET"
  else
    for ((i=0; i<${#MSG_ROLE[@]}; i++)); do
      local role="${MSG_ROLE[i]}" text="${MSG_TEXT[i]}"
      if [[ "$role" == "user" ]]; then
        printf '  %s▶ You:%s ' "$B_AMBER" "$RESET"
      else
        printf '  %s✦ Wizard:%s ' "$B_GREEN" "$RESET"
      fi
      wrap_print "$text" "$((TERM_W - 8))" 0 | sed 's/^/  /'
      echo ""
    done
  fi
  hr "" "$TERM_W"
  read -n 1 -s -r -p "  Press any key to return..."
}

_tool_diff_viewer() {
  clear_screen
  printf '\n  %s%sDiff Crystal%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  printf '  %sFile 1:%s ' "$P_GREEN" "$RESET"
  local f1 f2
  read -r f1
  printf '  %sFile 2:%s ' "$P_GREEN" "$RESET"
  read -r f2
  if [[ ! -f "$f1" || ! -f "$f2" ]]; then
    printf '  %sBoth files must exist.%s\n' "$P_RED" "$RESET"
    sleep 1
    return
  fi
  hr "Diff" "$TERM_W"
  diff "$f1" "$f2" | while IFS= read -r line; do
    if [[ "$line" == \>* ]]; then
      printf '  %s%s%s\n' "$P_GREEN" "$line" "$RESET"
    elif [[ "$line" == \<* ]]; then
      printf '  %s%s%s\n' "$P_RED" "$line" "$RESET"
    else
      printf '  %s%s%s\n' "$P_GREY" "$line" "$RESET"
    fi
  done
  hr "" "$TERM_W"
  read -n 1 -s -r -p "  Press any key to return..."
}

# Write the current conversation out to a session file. Echoes the path and
# returns 1 if there is nothing to save. quiet=1 suppresses the notice.
write_session_file() {
  local quiet=${1:-0}
  if (( ${#MSG_ROLE[@]} == 0 )); then
    return 1
  fi
  local ts
  ts=$(date '+%Y%m%d_%H%M%S')
  local outfile="${SESSION_DIR}/session-${ts}.txt"
  {
    echo "# Ollama RPG session — $ts"
    echo "# Model: ${CHAR[model]}"
    echo ""
    for ((i=0; i<${#MSG_ROLE[@]}; i++)); do
      if [[ "${MSG_ROLE[i]}" == "user" ]]; then
        echo "▶ You:"
      else
        echo "✦ Wizard:"
      fi
      echo "${MSG_TEXT[i]}"
      echo ""
    done
  } > "$outfile"
  if (( quiet == 0 )); then
    printf '  %sSaved to: %s%s\n' "$P_GREEN" "$outfile" "$RESET"
    sleep 2
  fi
  echo "$outfile"
}

# Quiet checkpoint used at quit/EOF; ignores empty conversations.
auto_save_session() {
  (( ${#MSG_ROLE[@]} == 0 )) && return 0
  write_session_file 1 >/dev/null 2>&1 || true
}

_tool_save_session() {
  write_session_file 0 || printf '  %sNo conversation to save.%s\n' "$P_RED" "$RESET"
}

# ── v2 tools ────────────────────────────────────────────────────────────────

_tool_man() {
  clear_screen
  printf '\n  %s%sMan Page Oracle%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  if ! command -v man >/dev/null 2>&1; then
    printf '  %sNo man binary available on this system.%s\n' "$P_RED" "$RESET"
    sleep 1; read -n 1 -s -r -p "  Press any key to return..."; return
  fi
  printf '  %sEnter a man page (e.g. grep):%s ' "$P_GREEN" "$RESET"
  local page
  read -r page
  [[ -z "$page" ]] && { read -n 1 -s -r -p "  Press any key to return..."; return; }
  if man "$page" >/dev/null 2>&1; then
    man "$page" | col -b 2>/dev/null | head -60 | while IFS= read -r line; do
      printf '  %s%s%s\n' "$P_GREEN" "$line" "$RESET"
    done
  else
    printf '  %sNo manual entry for %s.%s\n' "$P_RED" "$page" "$RESET"
  fi
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}

_tool_git() {
  clear_screen
  printf '\n  %s%sGit Grimoire%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  if ! command -v git >/dev/null 2>&1; then
    printf '  %sNo git binary available.%s\n' "$P_RED" "$RESET"
    sleep 1; read -n 1 -s -r -p "  Press any key to return..."; return
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '  %sNot inside a git repository.%s\n' "$P_AMBER" "$RESET"
    sleep 1; read -n 1 -s -r -p "  Press any key to return..."; return
  fi
  printf '  %sBranch:%s %s%s%s\n' "$P_AMBER" "$RESET" "$P_GREEN" "$(git branch --show-current 2>/dev/null)" "$RESET"
  printf '  %sStatus:%s\n' "$P_AMBER" "$RESET"
  git status --short 2>/dev/null | head -20 | while IFS= read -r line; do
    printf '  %s%s%s\n' "$P_GREEN" "$line" "$RESET"
  done
  echo ""
  printf '  %sRecent commits:%s\n' "$P_AMBER" "$RESET"
  git log --oneline -8 2>/dev/null | while IFS= read -r line; do
    printf '  %s%s%s\n' "$P_CYAN" "$line" "$RESET"
  done
  hr "" "$TERM_W"
  read -n 1 -s -r -p "  Press any key to return..."
}

_tool_search() {
  clear_screen
  printf '\n  %s%sRune Search%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  printf '  %sEnter a pattern to grep in the current directory:%s ' "$P_GREEN" "$RESET"
  local pat
  read -r pat
  [[ -z "$pat" ]] && { read -n 1 -s -r -p "  Press any key to return..."; return; }
  printf '  %sSearching for:%s %s%s%s\n' "$P_AMBER" "$RESET" "$P_GOLD" "$pat" "$RESET"
  grep -rIn --exclude-dir=.git --exclude-dir=node_modules "$pat" . 2>/dev/null | head -25 | while IFS= read -r line; do
    printf '  %s%s%s\n' "$P_GREEN" "$line" "$RESET"
  done
  hr "" "$TERM_W"
  read -n 1 -s -r -p "  Press any key to return..."
}

_tool_spell() {
  clear_screen
  printf '\n  %s%sSpellcheck Scroll%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  if (( ${#MSG_TEXT[@]} == 0 )); then
    printf '  %sNo response to spellcheck yet.%s\n' "$P_GREY" "$RESET"
    sleep 1; read -n 1 -s -r -p "  Press any key to return..."; return
  fi
  if ! command -v aspell >/dev/null 2>&1; then
    printf '  %saspell not installed; cannot spellcheck.%s\n' "$P_AMBER" "$RESET"
    sleep 1; read -n 1 -s -r -p "  Press any key to return..."; return
  fi
  local last="${MSG_TEXT[${#MSG_TEXT[@]}-1]}"
  local misses
  misses=$(printf '%s' "$last" | aspell list 2>/dev/null | sort -u | tr '\n' ' ')
  if [[ -z "$misses" ]]; then
    printf '  %sNo spelling mistakes found.%s\n' "$P_GREEN" "$RESET"
  else
    printf '  %sPossible misspellings:%s %s%s%s\n' "$P_AMBER" "$RESET" "$P_RED" "$misses" "$RESET"
  fi
  hr "" "$TERM_W"
  read -n 1 -s -r -p "  Press any key to return..."
}
