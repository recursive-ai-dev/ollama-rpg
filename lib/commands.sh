# ═══════════════════════════════════════════════════════════════════════════
# lib/commands.sh — slash-command handling and command sub-screens
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_COMMANDS:-}" ]] && return
declare -g _OLlama_RPG_COMMANDS=1

# ── Challenge / boss content (self-contained, plays offline) ─────────────────
# Format: id|question|optA|optB|optC|optD|answer(1-4)
declare -ga CHALLENGES=(
  "c1|What is the time complexity of binary search on a sorted array?|O(n)|O(log n)|O(n log n)|O(1)|2"
  "c2|Which keyword creates an immutable binding in JavaScript?|let|var|const|static|3"
  "c3|In Git, which command rewrites committed history?|git merge|git rebase|git pull|git fetch|2"
  "c4|What does SQL's PRIMARY KEY enforce?|Unique + not null|Sorting|Index only|Nullable|1"
  "c5|Which data structure offers O(1) average insert/lookup?|Balanced tree|Linked list|Hash map|Array|3"
  "c6|What does 'idempotent' mean for an API call?|It is fast|Repeating it has same effect|It uses JSON|It is secure|2"
  "c7|In Python, what does a generator yield?|An exception|A value and pauses|Nothing|A class|2"
  "c8|What is a race condition?|A fast sort|Undetermined output from timing|Version conflict|Memory leak|2"
  "c9|Which HTTP status means 'Not Found'?|200|301|404|500|3"
  "c10|What does Big-O notation describe?|Exact runtime|Upper bound growth|Memory use|Line count|2"
)

declare -ga BOSSES=(
  "b1|The Legacy Dragon asks: 'I have 1000 entries. Which is fastest to find if sorted?'|Linear scan|Binary search|Random guess|Sort then cry|2"
  "b2|The Concurrency Wyrm asks: 'Two threads share state without locks. What looms?'|Free lunch|Race condition|Clean code|Cache hit|2"
  "b3|The Memory Hydra asks: 'You allocate but never free. What devours you?'|Speed|Memory leak|Type safety|Stack overflow|2"
  "b4|The Refactor Behemoth asks: 'When is duplication acceptable?'|Never, ever|When abstractions cost more|Always|In tests only|2"
  "b5|The Security Kraken asks: 'User input goes straight into a query. What bites?'|SQL injection|XSS only|Nothing|CSRF|1"
)

handle_command() {
  local input="$1"
  local cmd args
  cmd="${input%% *}"
  args="${input#* }"
  [[ "$args" == "$input" ]] && args=""

  case "$cmd" in
    /help|h|?)              _cmd_help ;;
    /skills|/skill)         skill_tree ;;
    /talents|/talent)
      if (( ${CHAR[talent_points]} > 0 )); then talent_chooser
      else printf '  %sNo talent points available. Level up to earn more.%s\n' "$P_AMBER" "$RESET"; sleep 1; fi ;;
    /model)                 model_picker ;;
    /persona)
      if [[ -z "$args" ]]; then _list_personas; else _set_persona "$args"; fi ;;
    /prompt)
      if [[ -z "$args" ]]; then _list_system_prompts; else _set_system_prompt "$args"; fi ;;
    /quest|/quests)
      if [[ "$args" == "generate" ]]; then
        gen_quest
      else
        quest_log
      fi ;;
    /sessions)          _cmd_sessions ;;
    /status|/char|/sheet)   status_screen ;;
    /inv|/inventory)        inventory_screen ;;
    /ach|/achievements)     achievement_screen ;;
    /lore)
      if [[ -n "$args" ]]; then lore_show "$args"; else lore_screen; fi ;;
    /use)                   use_item "$args" ;;
    /challenge)             _cmd_challenge ;;
    /boss)                  _cmd_boss ;;
    /save)
      save_state
      printf '  %s✓ Game saved to %s%s\n' "$P_GREEN" "$SAVE_FILE" "$RESET"
      sleep 1 ;;
    /clear)
      MSG_ROLE=(); MSG_TEXT=()
      printf '  %sConversation cleared.%s\n' "$P_AMBER" "$RESET"
      sleep 1 ;;
    /snippet)
      if [[ -n "$args" ]]; then
        local subcmd="${args%% *}" name="${args#* }"
        if [[ "$subcmd" == "save" && -n "$name" && "$name" != "$args" ]]; then
          mkdir -p "$SNIPPET_DIR"
          printf '  %sEnter snippet content (Ctrl-D to end):%s\n' "$P_GREEN" "$RESET"
          cat > "${SNIPPET_DIR}/${name}.txt"
          printf '  %s✓ Snippet saved.%s\n' "$P_GREEN" "$RESET"
        else
          run_shell_tool "snippet_library"
        fi
      else
        run_shell_tool "snippet_library"
      fi ;;
    /file)    run_shell_tool "file_browser" ;;
    /history) run_shell_tool "history" ;;
    /diff)    run_shell_tool "diff_view" ;;
    /man)     run_shell_tool "man" ;;
    /git)     run_shell_tool "git" ;;
    /search)  run_shell_tool "search" ;;
    /spell)   run_shell_tool "spell" ;;
    /quit|/exit|/q)
      auto_save_session
      save_state
      printf '\n  %s%s⚔  Farewell, brave coder. May your code compile on the first try.  ⚔%s\n\n' "$B_GOLD" "$BOLD" "$RESET"
      exit 0 ;;
    *)
      printf '  %sUnknown command: %s (try /help)%s\n' "$P_RED" "$cmd" "$RESET"
      sleep 1 ;;
  esac
}

_cmd_help() {
  clear_screen
  printf '\n  %s%s⚔  CODEX OF COMMANDS  ⚔%s\n\n' "$B_GOLD" "$BOLD" "$RESET"

  hr "Conversation" "$TERM_W"
  printf '  %s(text)%s              Send a message to your AI mentor\n' "$P_GREEN" "$RESET"
  printf '  %s/clear%s              Clear the conversation log\n' "$P_GREEN" "$RESET"
  printf '  %s/save%s               Save game state\n' "$P_GREEN" "$RESET"
  printf '  %s/history%s            Browse full conversation history\n' "$P_GREEN" "$RESET"
  printf '  %s/file%s               View a file in the TUI\n' "$P_GREEN" "$RESET"
  printf '  %s/diff%s               Compare two files\n' "$P_GREEN" "$RESET"
  printf '  %s/snippet%s            Browse or save code snippets\n' "$P_GREEN" "$RESET"
  printf '  %s/man%s %s/git%s %s/search%s %s/spell%s   New shell tools\n' "$P_GREEN" "$RESET" "$P_GREEN" "$RESET" "$P_GREEN" "$RESET" "$P_GREEN" "$RESET"

  hr "Character" "$TERM_W"
  printf '  %s/status%s             View character sheet\n' "$P_GREEN" "$RESET"
  printf '  %s/skills%s             Open the skill grimoire\n' "$P_GREEN" "$RESET"
  printf '  %s/talents%s            Spend talent points\n' "$P_GREEN" "$RESET"
  printf '  %s/quest%s              View quest log\n' "$P_GREEN" "$RESET"
  printf '  %s/quest generate%s     Have the Oracle create a custom quest\n' "$P_GREEN" "$RESET"
  printf '  %s/model%s              Change your Ollama model\n' "$P_GREEN" "$RESET"
  printf '  %s/persona%s            Set AI persona (/persona <id>)\n' "$P_GREEN" "$RESET"
  printf '  %s/prompt%s             Set system prompt (/prompt <id>)\n' "$P_GREEN" "$RESET"

  hr "World (v2)" "$TERM_W"
  printf '  %s/inv%s                Open your satchel\n' "$P_GREEN" "$RESET"
  printf '  %s/use <id>%s           Use an item (e.g. /use potion_hp)\n' "$P_GREEN" "$RESET"
  printf '  %s/ach%s                View achievements\n' "$P_GREEN" "$RESET"
  printf '  %s/lore%s               Read the world codex (/lore <n>)\n' "$P_GREEN" "$RESET"
  printf '  %s/sessions%s            Browse saved conversations\n' "$P_GREEN" "$RESET"
  printf '  %s/challenge%s          Duel a riddle for XP\n' "$P_GREEN" "$RESET"
  printf '  %s/boss%s               Face a Code Dragon for glory\n' "$P_GREEN" "$RESET"

  hr "System" "$TERM_W"
  printf '  %s/help%s               Show this codex\n' "$P_GREEN" "$RESET"
  printf '  %s/quit%s               Save and exit\n' "$P_GREEN" "$RESET"

  hr "" "$TERM_W"
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}

# ── Persona / system prompt listings ────────────────────────────────────────

_list_personas() {
  clear_screen
  printf '\n  %s%sPersonas%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  printf '  %sdefault%s — No persona\n' "$P_GREY" "$RESET"
  for skill in "${SKILLS[@]}"; do
    local sid sname sdesc slvl stype
    IFS='|' read -r sid sname _ sdesc slvl stype _ <<< "$skill"
    [[ "$stype" != "persona" ]] && continue
    local status=""
    if [[ ",${CHAR[skills]}," != *",$sid,"* ]]; then status="locked"
    elif [[ "${CHAR[persona]}" == "$sid" ]]; then status="ACTIVE"
    else status="owned"; fi
    printf '  %s%-18s%s [%s] %s — %s\n' "$B_GREEN" "$sid" "$RESET" "$status" "$sname" "$sdesc"
  done
  hr "" "$TERM_W"
  printf '  %sUse: /persona <id>%s\n' "$P_AMBER" "$RESET"
  read -n 1 -s -r -p "  Press any key to return..."
}

_set_persona() {
  local sid=$1
  if [[ "$sid" == "default" ]]; then
    CHAR[persona]="default"; save_state
    printf '  %sPersona reset to default.%s\n' "$P_AMBER" "$RESET"; sleep 1; return
  fi
  if [[ ",${CHAR[skills]}," != *",$sid,"* ]]; then
    printf '  %sPersona not unlocked.%s\n' "$P_RED" "$RESET"; sleep 1; return
  fi
  local stype
  stype=$(skill_field "$sid" type)
  if [[ "$stype" != "persona" ]]; then
    printf '  %sNot a persona.%s\n' "$P_RED" "$RESET"; sleep 1; return
  fi
  CHAR[persona]="$sid"; save_state
  printf '  %sPersona set: %s%s\n' "$P_GREEN" "$(skill_field "$sid" name)" "$RESET"; sleep 1
}

_list_system_prompts() {
  clear_screen
  printf '\n  %s%sSystem Prompts%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  printf '  %sbase%s — No system prompt\n' "$P_GREY" "$RESET"
  for skill in "${SKILLS[@]}"; do
    local sid sname sdesc slvl stype
    IFS='|' read -r sid sname _ sdesc slvl stype _ <<< "$skill"
    [[ "$stype" != "system" ]] && continue
    local status=""
    if [[ ",${CHAR[skills]}," != *",$sid,"* ]]; then status="locked"
    elif [[ "${CHAR[system_prompt]}" == "$sid" ]]; then status="ACTIVE"
    else status="owned"; fi
    printf '  %s%-18s%s [%s] %s — %s\n' "$B_GREEN" "$sid" "$RESET" "$status" "$sname" "$sdesc"
  done
  hr "" "$TERM_W"
  printf '  %sUse: /prompt <id>%s\n' "$P_AMBER" "$RESET"
  read -n 1 -s -r -p "  Press any key to return..."
}

_set_system_prompt() {
  local sid=$1
  if [[ "$sid" == "base" ]]; then
    CHAR[system_prompt]="base"; save_state
    printf '  %sSystem prompt reset to base.%s\n' "$P_AMBER" "$RESET"; sleep 1; return
  fi
  if [[ ",${CHAR[skills]}," != *",$sid,"* ]]; then
    printf '  %sSystem prompt not unlocked.%s\n' "$P_RED" "$RESET"; sleep 1; return
  fi
  local stype
  stype=$(skill_field "$sid" type)
  if [[ "$stype" != "system" ]]; then
    printf '  %sNot a system prompt.%s\n' "$P_RED" "$RESET"; sleep 1; return
  fi
  CHAR[system_prompt]="$sid"; save_state
  printf '  %sSystem prompt set: %s%s\n' "$P_GREEN" "$(skill_field "$sid" name)" "$RESET"; sleep 1
}

# ── Challenge / boss engine ──────────────────────────────────────────────────

# Run a challenge from the named pool array. reward_xp and reward_gold scale
# the payout; boss fights deal HP damage on failure.
_run_challenge() {
  local pool_name=$1 reward_xp=$2 reward_gold=$3 is_boss=$4
  local -a pool
  eval "pool=(\"\${${pool_name}[@]}\")"

  local pick="${pool[$(( RANDOM % ${#pool[@]} ))]}"
  local cid question oa ob oc od ans
  IFS='|' read -r cid question oa ob oc od ans <<< "$pick"

  clear_screen
  box_banner "$B_PURPLE" "$question" \
    "  ${P_GOLD}[1]${RESET} $oa" \
    "  ${P_GOLD}[2]${RESET} $ob" \
    "  ${P_GOLD}[3]${RESET} $oc" \
    "  ${P_GOLD}[4]${RESET} $od"
  printf '  %sYour answer (1-4):%s ' "$P_GREEN" "$RESET"
  local choice
  read -r choice

  if [[ "$choice" == "$ans" ]]; then
    local xp=$reward_xp
    if has_talent "duelist" && (( is_boss == 0 )); then
      xp=$(( xp * 2 ))
      printf '  %s%s⚔ Duelist talent: challenge reward doubled!%s\n' "$B_GOLD" "$BOLD" "$RESET"
    fi
    if (( is_boss == 1 )); then
      CHAR[bosses_slain]=$(( ${CHAR[bosses_slain]} + 1 ))
      grant_achievement "dragonslayer_ach"
      printf '  %s%s🐉 CODE DRAGON SLAIN!%s\n' "$B_RED" "$BOLD" "$RESET"
    else
      CHAR[challenges_won]=$(( ${CHAR[challenges_won]} + 1 ))
      grant_achievement "riddler"
      printf '  %s%s✦ Correct!%s\n' "$B_GREEN" "$BOLD" "$RESET"
    fi
    CHAR[gold]=$(( ${CHAR[gold]} + reward_gold ))
    apply_xp "$xp"
  else
    if (( is_boss == 1 )); then
      local dmg=$(( 15 + RANDOM % 20 ))
      CHAR[hp]=$(( ${CHAR[hp]} - dmg ))
      (( ${CHAR[hp]} < 0 )) && CHAR[hp]=0
      printf '  %s%s🐉 The dragon wounds you for %d HP! (now %d/%d)%s\n' "$B_RED" "$BOLD" "$dmg" "${CHAR[hp]}" "${CHAR[hp_max]}" "$RESET"
    else
      printf '  %s%s✗ Incorrect. The conclave sighs.%s\n' "$P_RED" "$BOLD" "$RESET"
    fi
    sleep 2
    save_state
  fi
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}

_cmd_challenge() { _run_challenge CHALLENGES 100 25 0; }
_cmd_boss()      { _run_challenge BOSSES 300 150 1; }

# ── Saved sessions browser ───────────────────────────────────────────────────

_cmd_sessions() {
  clear_screen
  printf '\n  %s%sMemory Vault — Saved Sessions%s\n' "$B_GOLD" "$BOLD" "$RESET"
  hr "" "$TERM_W"
  local files=()
  local f
  for f in "$SESSION_DIR"/session-*.txt; do
    [[ -f "$f" ]] && files+=("$f")
  done
  if (( ${#files[@]} == 0 )); then
    printf '  %sNo saved sessions yet. They are written automatically on quit,%s\n' "$P_GREY" "$RESET"
    printf '  %sor manually with the Scribe%s Quill skill (/history).%s\n' "$P_GREY" "$RESET" "$RESET"
    hr "" "$TERM_W"
    read -n 1 -s -r -p "  Press any key to return..."
    return
  fi
  local idx=1
  for f in "${files[@]}"; do
    local first_line
    first_line=$(grep -m1 '^▶' "$f" 2>/dev/null | sed 's/^▶ You: //' | head -c 60)
    printf '  %s[%d]%s %s%s%s\n' "$P_GOLD" "$idx" "$RESET" "$P_GREEN" "$(basename "$f")" "$RESET"
    [[ -n "$first_line" ]] && printf '       %s%s...%s\n' "$P_GREY" "$first_line" "$RESET"
    ((idx++))
  done
  printf '   %sq%s to return%s\n' "$P_GOLD" "$RESET" "$RESET"
  hr "" "$TERM_W"
  printf '  %sView session number:%s ' "$P_GREEN" "$RESET"
  local choice
  read -r choice
  [[ "$choice" == "q" || -z "$choice" ]] && return
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#files[@]} )); then
    printf '  %sInvalid choice.%s\n' "$P_RED" "$RESET"
    sleep 1
    return
  fi
  clear_screen
  local chosen="${files[$((choice - 1))]}"
  printf '\n  %s%s━━ %s ━━%s\n\n' "$B_GOLD" "$BOLD" "$(basename "$chosen")" "$RESET"
  while IFS= read -r line; do
    if [[ "$line" == "▶ You:" ]]; then
      printf '  %s▶ You:%s ' "$B_AMBER" "$RESET"
    elif [[ "$line" == "✦ Wizard:" ]]; then
      printf '  %s✦ Wizard:%s ' "$B_GREEN" "$RESET"
    elif [[ -z "$line" ]]; then
      echo ""
    else
      wrap_print "$line" "$((TERM_W - 8))" 0 | sed 's/^/  /'
      echo ""
    fi
  done < "$chosen"
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}
