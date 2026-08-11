# ═══════════════════════════════════════════════════════════════════════════
# lib/screens.sh — full-screen modals and menus
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_SCREENS:-}" ]] && return
declare -g _OLlama_RPG_SCREENS=1

# ─────────────────────────────────────────────────────────────────────────────
# SPLASH SCREEN
# ─────────────────────────────────────────────────────────────────────────────

splash_screen() {
  clear_screen
  cat <<'SPLASH'

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                                                          @
    @     ███╗   ███╗██╗   ██╗███╗   ███╗ █████╗  ██████╗ ██╗   @
    @     ████╗ ████║██║   ██║████╗ ████║██╔══██╗██╔════╝ ██║   @
    @     ██╔████╔██║██║   ██║██╔████╔██║███████║██║  ███╗██║   @
    @     ██║╚██╔╝██║██║   ██║██║╚██╔╝██║██╔══██║██║   ██║╚═╝   @
    @     ██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║██║  ██║╚██████╔╝██╗   @
    @     ╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝   @
    @                                                          @
    @      ██████╗  ██████╗ ██╗  ██╗██╗   ██╗                   @
    @      ██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝                   @
    @      ██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝                    @
    @      ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝                     @
    @      ██║  ██║╚██████╔╝██╔╝ ██╗   ██║                      @
    @      ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝                      @
    @                                                          @
    @          a Fantasy Coding RPG for the Terminal           @
    @                                                          @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

SPLASH
  printf '  %s%sVersion %s  •  Bash-only  •  No dependencies  •  Saves to ~/.ollama-rpg-save%s\n\n' \
    "$P_DIM_GREEN" "$BOLD" "$SCRIPT_VERSION" "$RESET"
}

# ─────────────────────────────────────────────────────────────────────────────
# LEVEL UP ANIMATION
# ─────────────────────────────────────────────────────────────────────────────

level_up_animation() {
  local lvl=${CHAR[level]}
  local title
  title=$(class_title "$lvl")

  echo ""
  printf '%s%s╔══════════════════════════════════════════════════════════════╗%s\n' "$B_GOLD" "$RESET"
  printf '%s%s║%s%s   ✦  LEVEL UP!  ✦   You are now Level %s  —  %s  %s%s║%s\n' \
    "$B_GOLD" "$RESET" "$P_GOLD" "$BOLD" "$lvl" "$title" "$P_GOLD" "$B_GOLD" "$RESET"
  printf '%s%s║%s%s   HP max +10 → %d    MP max +5 → %d    Gold +%d       %s%s║%s\n' \
    "$B_GOLD" "$RESET" "$P_GREEN" "$BOLD" "${CHAR[hp_max]}" "${CHAR[mp_max]}" "$(( 20 * lvl ))" "$P_GOLD" "$B_GOLD" "$RESET"
  printf '%s%s║%s%s   Talent Points: %d available                       %s%s║%s\n' \
    "$B_GOLD" "$RESET" "$P_AMBER" "$BOLD" "${CHAR[talent_points]}" "$P_GOLD" "$B_GOLD" "$RESET"
  printf '%s%s╚══════════════════════════════════════════════════════════════╝%s\n' "$B_GOLD" "$RESET"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# TALENT CHOOSER (modal screen)
# ─────────────────────────────────────────────────────────────────────────────

talent_chooser() {
  while (( ${CHAR[talent_points]} > 0 )); do
    clear_screen
    printf '\n  %s%s⚔  TALENT GUILD  ⚔%s\n' "$B_GOLD" "$BOLD" "$RESET"
    printf '  %sYou have %d talent point(s) to spend.%s\n\n' "$P_AMBER" "${CHAR[talent_points]}" "$RESET"

    hr "Available Talents" "$TERM_W"

    local idx=1
    local available=()
    for talent in "${TALENTS[@]}"; do
      local tid tname tdesc tlvl
      IFS='|' read -r tid tname tdesc tlvl <<< "$talent"

      [[ ",${CHAR[talents]}," == *",$tid,"* ]] && continue
      (( ${CHAR[level]} < tlvl )) && continue

      available+=("$tid")
      printf '  %s[%d]%s %s%s%s %s(Lv.%d)%s — %s\n' \
        "$P_GOLD" "$idx" "$RESET" \
        "$B_GREEN" "$tname" "$RESET" \
        "$P_GREY" "$tlvl" "$RESET" \
        "$tdesc"
      ((idx++))
    done

    if (( ${#available[@]} == 0 )); then
      printf '\n  %sNo talents available at your current level.%s\n' "$P_GREY" "$RESET"
      printf '  %sTalent points will be saved for later.%s\n\n' "$P_DIM_GREEN" "$RESET"
      read -n 1 -s -r -p "  Press any key to continue..."
      return
    fi

    hr "" "$TERM_W"
    printf '  %sCurrently owned:%s %s\n' "$P_AMBER" "$RESET" "${CHAR[talents]:-none}"
    hr "" "$TERM_W"
    printf '  %sChoose a talent by number (or s to skip):%s ' "$P_GREEN" "$RESET"

    local choice
    read -r choice || choice="s"   # EOF: skip instead of looping forever

    if [[ "$choice" == "s" || "$choice" == "S" ]]; then
      return
    fi

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#available[@]} )); then
      printf '  %sInvalid choice.%s\n' "$P_RED" "$RESET"
      sleep 1
      continue
    fi

    local chosen="${available[$((choice - 1))]}"
    local tname
    tname=$(talent_field "$chosen" name)

    if [[ -n "${CHAR[talents]}" ]]; then
      CHAR[talents]="${CHAR[talents]},$chosen"
    else
      CHAR[talents]="$chosen"
    fi
    CHAR[talent_points]=$(( ${CHAR[talent_points]} - 1 ))

    case "$chosen" in
      tough)
        CHAR[hp_max]=$(( ${CHAR[hp_max]} + 20 ))
        CHAR[hp]=$(( ${CHAR[hp]} + 20 ))
        ;;
      arcane)
        CHAR[mp_max]=$(( ${CHAR[mp_max]} + 20 ))
        CHAR[mp]=$(( ${CHAR[mp]} + 20 ))
        ;;
      lorekeeper)
        local starter
        starter=$(roll_item_drop)
        if [[ -n "$starter" ]]; then
          inv_add "$starter" 1
          printf '\n  %s%s✦ A starter item appears in your pack: %s!%s\n' \
            "$B_PURPLE" "$BOLD" "$(item_field "$starter" name)" "$RESET"
        fi
        ;;
    esac

    printf '\n  %s%s✦ Talent acquired: %s!%s\n' "$B_GOLD" "$BOLD" "$tname" "$RESET"
    sleep 1
    save_state
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# SKILL TREE (modal screen)
# ─────────────────────────────────────────────────────────────────────────────

skill_tree() {
  while true; do
    clear_screen
    printf '\n  %s%s⚔  SKILL GRIMOIRE  ⚔%s\n' "$B_GOLD" "$BOLD" "$RESET"
    printf '  %sSpend gold to unlock skills. Toggle them active to use.%s\n\n' "$P_DIM_GREEN" "$RESET"

    hr "Coding Tools" "$TERM_W"
    _skill_print_section "coding"

    hr "System Prompts" "$TERM_W"
    _skill_print_section "prompt"

    hr "Shell Utilities" "$TERM_W"
    _skill_print_section "shell"

    hr "Personas" "$TERM_W"
    _skill_print_section "persona"

    hr "" "$TERM_W"
    printf '  %sGold:%s %s%d%s   %sActive Skills:%s %s\n' \
      "$P_AMBER" "$RESET" "$P_GOLD" "${CHAR[gold]}" "$RESET" \
      "$P_AMBER" "$RESET" "${CHAR[active_skills]:-none}"
    hr "" "$TERM_W"
    printf '  %sCommands:%s unlock <id> | toggle <id> | persona <id> | prompt <id> | q\n' "$P_GREEN" "$RESET"
    printf '  > '
    local cmd
    read -r cmd || cmd="q"   # EOF: leave the grimoire instead of looping

    if [[ "$cmd" == "q" || -z "$cmd" ]]; then
      return
    fi

    _skill_handle_command $cmd
  done
}

_skill_print_section() {
  local cat=$1
  local idx=1
  for skill in "${SKILLS[@]}"; do
    local sid sname scat sdesc slvl stype sarg
    IFS='|' read -r sid sname scat sdesc slvl stype sarg <<< "$skill"
    [[ "$scat" != "$cat" ]] && continue

    local status="" status_color=""
    if [[ ",${CHAR[skills]}," == *",$sid,"* ]]; then
      if [[ "$stype" == "prefix" ]]; then
        if [[ ",${CHAR[active_skills]}," == *",$sid,"* ]]; then
          status="ACTIVE"; status_color="$P_GREEN"
        else
          status="owned"; status_color="$P_AMBER"
        fi
      elif [[ "$stype" == "system" ]]; then
        if [[ "${CHAR[system_prompt]}" == "$sid" ]]; then
          status="ACTIVE"; status_color="$P_GREEN"
        else
          status="owned"; status_color="$P_AMBER"
        fi
      elif [[ "$stype" == "persona" ]]; then
        if [[ "${CHAR[persona]}" == "$sid" ]]; then
          status="ACTIVE"; status_color="$P_GREEN"
        else
          status="owned"; status_color="$P_AMBER"
        fi
      else
        status="owned"; status_color="$P_AMBER"
      fi
    else
      if (( ${CHAR[level]} < slvl )); then
        status="locked (Lv.$slvl)"; status_color="$P_GREY"
      else
        local cost=$(( slvl * 25 ))
        status="cost ${cost}g"; status_color="$P_GOLD"
      fi
    fi

    printf '  %s%-22s%s %s[%s]%s — %s\n' \
      "$B_GREEN" "$sname" "$RESET" \
      "$status_color" "$status" "$RESET" \
      "$sdesc"
    printf '  %s(id: %s)%s\n' "$P_GREY" "$sid" "$RESET"
  done
  echo ""
}

_skill_handle_command() {
  local action=$1 sid=$2
  if [[ -z "$sid" ]]; then
    printf '  %sUsage: unlock <id> | toggle <id> | persona <id> | prompt <id>%s\n' "$P_RED" "$RESET"
    sleep 1
    return
  fi

  local sname slvl stype
  sname=$(skill_field "$sid" name 2>/dev/null) || {
    printf '  %sUnknown skill: %s%s\n' "$P_RED" "$sid" "$RESET"
    sleep 1
    return
  }
  slvl=$(skill_field "$sid" lvl)
  stype=$(skill_field "$sid" type)

  case "$action" in
    unlock)
      if [[ ",${CHAR[skills]}," == *",$sid,"* ]]; then
        printf '  %sAlready owned.%s\n' "$P_AMBER" "$RESET"
        sleep 1
        return
      fi
      if (( ${CHAR[level]} < slvl )); then
        printf '  %sRequires level %d.%s\n' "$P_RED" "$slvl" "$RESET"
        sleep 1
        return
      fi
      local cost=$(( slvl * 25 ))
      if (( ${CHAR[gold]} < cost )); then
        printf '  %sNeed %d gold (have %d).%s\n' "$P_RED" "$cost" "${CHAR[gold]}" "$RESET"
        sleep 1
        return
      fi
      CHAR[gold]=$(( ${CHAR[gold]} - cost ))
      if [[ -n "${CHAR[skills]}" ]]; then
        CHAR[skills]="${CHAR[skills]},$sid"
      else
        CHAR[skills]="$sid"
      fi
      if [[ "$stype" == "prefix" ]]; then
        if [[ -n "${CHAR[active_skills]}" ]]; then
          CHAR[active_skills]="${CHAR[active_skills]},$sid"
        else
          CHAR[active_skills]="$sid"
        fi
      fi
      printf '  %s%s✦ Unlocked: %s!%s\n' "$B_GOLD" "$BOLD" "$sname" "$RESET"
      save_state
      sleep 1
      ;;
    toggle)
      if [[ ",${CHAR[skills]}," != *",$sid,"* ]]; then
        printf '  %sSkill not unlocked.%s\n' "$P_RED" "$RESET"
        sleep 1
        return
      fi
      if [[ "$stype" != "prefix" ]]; then
        printf '  %sOnly coding prefix skills can be toggled.%s\n' "$P_RED" "$RESET"
        sleep 1
        return
      fi
      if [[ ",${CHAR[active_skills]}," == *",$sid,"* ]]; then
        local new_active=""
        local IFS=','
        read -ra ids <<< "${CHAR[active_skills]}"
        unset IFS
        for id in "${ids[@]}"; do
          [[ "$id" == "$sid" ]] && continue
          if [[ -n "$new_active" ]]; then new_active+=",$id"; else new_active="$id"; fi
        done
        CHAR[active_skills]="$new_active"
        printf '  %sDeactivated: %s%s\n' "$P_AMBER" "$sname" "$RESET"
      else
        if [[ -n "${CHAR[active_skills]}" ]]; then
          CHAR[active_skills]="${CHAR[active_skills]},$sid"
        else
          CHAR[active_skills]="$sid"
        fi
        printf '  %sActivated: %s%s\n' "$P_GREEN" "$sname" "$RESET"
      fi
      save_state
      sleep 1
      ;;
    persona)
      if [[ ",${CHAR[skills]}," != *",$sid,"* ]]; then
        printf '  %sSkill not unlocked.%s\n' "$P_RED" "$RESET"
        sleep 1
        return
      fi
      if [[ "$stype" != "persona" ]]; then
        printf '  %sNot a persona.%s\n' "$P_RED" "$RESET"
        sleep 1
        return
      fi
      if [[ "${CHAR[persona]}" == "$sid" ]]; then
        CHAR[persona]="default"
        printf '  %sPersona reset to default.%s\n' "$P_AMBER" "$RESET"
      else
        CHAR[persona]="$sid"
        printf '  %sPersona set: %s%s\n' "$P_GREEN" "$sname" "$RESET"
      fi
      save_state
      sleep 1
      ;;
    prompt)
      if [[ ",${CHAR[skills]}," != *",$sid,"* ]]; then
        printf '  %sSkill not unlocked.%s\n' "$P_RED" "$RESET"
        sleep 1
        return
      fi
      if [[ "$stype" != "system" ]]; then
        printf '  %sNot a system prompt.%s\n' "$P_RED" "$RESET"
        sleep 1
        return
      fi
      if [[ "${CHAR[system_prompt]}" == "$sid" ]]; then
        CHAR[system_prompt]="base"
        printf '  %sSystem prompt reset to base.%s\n' "$P_AMBER" "$RESET"
      else
        CHAR[system_prompt]="$sid"
        printf '  %sSystem prompt set: %s%s\n' "$P_GREEN" "$sname" "$RESET"
      fi
      save_state
      sleep 1
      ;;
    *)
      printf '  %sUnknown action: %s%s\n' "$P_RED" "$action" "$RESET"
      sleep 1
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# MODEL PICKER
# ─────────────────────────────────────────────────────────────────────────────

model_picker() {
  clear_screen
  printf '\n  %s%s⚔  CHOOSE YOUR FAMILIAR  ⚔%s\n' "$B_GOLD" "$BOLD" "$RESET"
  printf '  %sSelect which Ollama model will be your mentor.%s\n\n' "$P_DIM_GREEN" "$RESET"

  if ! ollama_check; then
    printf '  %s✗ Cannot reach Ollama at %s%s\n' "$P_RED" "$OLLAMA_URL" "$RESET"
    printf '  %sMake sure Ollama is running.%s\n' "$P_AMBER" "$RESET"
    printf '  %sYou can still browse skills, but chat will not work.%s\n\n' "$P_GREY" "$RESET"
    printf '  Enter a model name manually (or q to skip): '
    local m
    read -r m
    [[ "$m" == "q" || -z "$m" ]] && return 1
    CHAR[model]="$m"
    save_state
    return 0
  fi

  hr "Available Models" "$TERM_W"

  local models=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && models+=("$line")
  done < <(ollama_list_models)

  if (( ${#models[@]} == 0 )); then
    printf '  %sNo models found. Pull one with: ollama pull llama3.2%s\n' "$P_RED" "$RESET"
    printf '  Enter a model name manually (or q to skip): '
    local m
    read -r m
    [[ "$m" == "q" || -z "$m" ]] && return 1
    CHAR[model]="$m"
    save_state
    return 0
  fi

  local idx=1
  for m in "${models[@]}"; do
    printf '  %s[%d]%s %s%s%s\n' "$P_GOLD" "$idx" "$RESET" "$P_GREEN" "$m" "$RESET"
    ((idx++))
  done

  hr "" "$TERM_W"
  printf '  %sChoose by number: %s' "$P_GREEN" "$RESET"
  local choice
  read -r choice

  if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#models[@]} )); then
    printf '  %sInvalid choice.%s\n' "$P_RED" "$RESET"
    sleep 1
    return 1
  fi

  CHAR[model]="${models[$((choice - 1))]}"
  save_state
  printf '\n  %s%s✦ Familiar bound: %s%s\n' "$B_GOLD" "$BOLD" "${CHAR[model]}" "$RESET"
  sleep 1
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# QUEST LOG
# ─────────────────────────────────────────────────────────────────────────────

quest_log() {
  clear_screen
  printf '\n  %s%s⚔  QUEST LOG  ⚔%s\n\n' "$B_GOLD" "$BOLD" "$RESET"

  hr "Active Quests" "$TERM_W"
  for quest in "${QUESTS[@]}"; do
    local qid qname qdesc qgoal qxp qgold
    IFS='|' read -r qid qname qdesc qgoal qxp qgold <<< "$quest"

    [[ ",${CHAR[quests_completed]}," == *",$qid,"* ]] && continue

    local goal_type goal_val
    goal_type="${qgoal%%:*}"
    goal_val="${qgoal##*:}"

    local current
    current=$(metric_value "$goal_type")

    local pct=0
    (( goal_val > 0 )) && pct=$(( current * 100 / goal_val ))
    (( pct > 100 )) && pct=100

    printf '  %s%s%s — %s%s\n' "$B_GREEN" "$qname" "$RESET" "$P_GREEN" "$qdesc" "$RESET"
    printf '  %sProgress: %d/%d (%d%%)  Reward: %d XP, %d gold%s\n\n' \
      "$P_AMBER" "$current" "$goal_val" "$pct" "$qxp" "$qgold" "$RESET"
  done

  hr "Completed Quests" "$TERM_W"
  if [[ -z "${CHAR[quests_completed]:-}" ]]; then
    printf '  %sNone yet.%s\n' "$P_GREY" "$RESET"
  else
    local IFS=','
    read -ra completed <<< "${CHAR[quests_completed]}"
    unset IFS
    for qid in "${completed[@]}"; do
      for quest in "${QUESTS[@]}"; do
        local qid2 qname
        IFS='|' read -r qid2 qname _ <<< "$quest"
        if [[ "$qid2" == "$qid" ]]; then
          printf '  %s✓ %s%s\n' "$P_GREEN" "$qname" "$RESET"
        fi
      done
    done
  fi

  hr "" "$TERM_W"
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}

# ─────────────────────────────────────────────────────────────────────────────
# STATUS / CHARACTER SHEET
# ─────────────────────────────────────────────────────────────────────────────

status_screen() {
  clear_screen
  local lvl=${CHAR[level]}
  local title
  title=$(class_title "$lvl")
  local xp_needed
  xp_needed=$(xp_for_level "$lvl")

  printf '\n  %s%s⚔  CHARACTER SHEET  ⚔%s\n\n' "$B_GOLD" "$BOLD" "$RESET"

  hr "Identity" "$TERM_W"
  printf '  %sClass:%s %sLevel %d %s%s\n' "$P_AMBER" "$RESET" "$P_GREEN" "$lvl" "$title" "$RESET"
  printf '  %sFamiliar:%s %s%s%s\n' "$P_AMBER" "$RESET" "$P_GREEN" "${CHAR[model]:-none}" "$RESET"

  hr "Vital Stats" "$TERM_W"
  printf '  %sHP:%s %s%d/%d%s   %sMP:%s %s%d/%d%s\n' \
    "$P_RED" "$RESET" "$P_RED" "${CHAR[hp]}" "${CHAR[hp_max]}" "$RESET" \
    "$P_CYAN" "$RESET" "$P_CYAN" "${CHAR[mp]}" "${CHAR[mp_max]}" "$RESET"
  printf '  %sXP:%s %s%d/%d%s   %sGold:%s %s%d%s\n' \
    "$P_AMBER" "$RESET" "$P_GOLD" "${CHAR[xp]}" "$xp_needed" "$RESET" \
    "$P_AMBER" "$RESET" "$P_GOLD" "${CHAR[gold]}" "$RESET"

  hr "Activity" "$TERM_W"
  printf '  %sPrompts sent:%s %d   %sTokens received:%s %d\n' \
    "$P_AMBER" "$RESET" "${CHAR[prompts_sent]}" \
    "$P_AMBER" "$RESET" "${CHAR[tokens_received]}"
  printf '  %sQuests completed:%s %d   %sStreak:%s %d🔥\n' \
    "$P_AMBER" "$RESET" "${CHAR[quests_completed]:-0}" \
    "$P_AMBER" "$RESET" "${CHAR[streak]}"
  printf '  %sChallenges won:%s %d   %sBosses slain:%s %d   %sTalent points:%s %d\n' \
    "$P_AMBER" "$RESET" "${CHAR[challenges_won]}" \
    "$P_AMBER" "$RESET" "${CHAR[bosses_slain]}" \
    "$P_AMBER" "$RESET" "${CHAR[talent_points]}"

  hr "Owned Skills" "$TERM_W"
  if [[ -z "${CHAR[skills]:-}" ]]; then
    printf '  %sNone — visit the skill grimoire to learn some.%s\n' "$P_GREY" "$RESET"
  else
    local IFS=','
    read -ra ids <<< "${CHAR[skills]}"
    unset IFS
    for id in "${ids[@]}"; do
      local name cat
      name=$(skill_field "$id" name 2>/dev/null) || continue
      cat=$(skill_field "$id" cat)
      printf '  %s• %-22s%s %s(%s)%s\n' "$P_GREEN" "$name" "$RESET" "$P_GREY" "$cat" "$RESET"
    done
  fi

  hr "Owned Talents" "$TERM_W"
  if [[ -z "${CHAR[talents]:-}" ]]; then
    printf '  %sNone — earn talent points by leveling up.%s\n' "$P_GREY" "$RESET"
  else
    local IFS=','
    read -ra ids <<< "${CHAR[talents]}"
    unset IFS
    for id in "${ids[@]}"; do
      local name desc
      name=$(talent_field "$id" name 2>/dev/null) || continue
      desc=$(talent_field "$id" desc)
      printf '  %s• %-22s%s %s— %s%s\n' "$P_AMBER" "$name" "$RESET" "$P_GREY" "$desc" "$RESET"
    done
  fi

  hr "" "$TERM_W"
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}

# ─────────────────────────────────────────────────────────────────────────────
# INVENTORY SCREEN (v2)
# ─────────────────────────────────────────────────────────────────────────────

inventory_screen() {
  clear_screen
  printf '\n  %s%s⚔  SATCHEL OF HOLDINGS  ⚔%s\n\n' "$B_GOLD" "$BOLD" "$RESET"

  if [[ -z "${CHAR[inventory]:-}" ]]; then
    printf '  %sYour satchel is empty. Slay encounters and finish quests to find loot.%s\n' "$P_GREY" "$RESET"
  else
    hr "Items" "$TERM_W"
    local IFS=','
    read -ra entries <<< "${CHAR[inventory]}"
    unset IFS
    local idx=1
    for entry in "${entries[@]}"; do
      [[ -z "$entry" ]] && continue
      local iid=${entry%%:*} icnt=${entry##*:}
      local iname idesc irarity
      iname=$(item_field "$iid" name 2>/dev/null || echo "$iid")
      idesc=$(item_field "$iid" desc 2>/dev/null || echo "")
      irarity=$(item_field "$iid" rarity 2>/dev/null || echo "common")
      printf '  %s[%d]%s %s%s%s %s(x%d)%s %s[%s]%s — %s\n' \
        "$P_GOLD" "$idx" "$RESET" \
        "$B_GREEN" "$iname" "$RESET" \
        "$P_AMBER" "$icnt" "$RESET" \
        "$P_PURPLE" "$irarity" "$RESET" \
        "$P_GREY" "$idesc"
      ((idx++))
    done
    hr "" "$TERM_W"
    printf '  %sUse an item: /use <id>%s\n' "$P_GREEN" "$RESET"
  fi

  hr "" "$TERM_W"
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}

# ─────────────────────────────────────────────────────────────────────────────
# ACHIEVEMENTS SCREEN (v2)
# ─────────────────────────────────────────────────────────────────────────────

achievement_screen() {
  clear_screen
  printf '\n  %s%s⚔  HALL OF LEGENDS  ⚔%s\n\n' "$B_PURPLE" "$BOLD" "$RESET"

  local total=${#ACHIEVEMENTS[@]}
  local earned=0
  hr "Achievements" "$TERM_W"
  for ach in "${ACHIEVEMENTS[@]}"; do
    local aid aname adesc
    IFS='|' read -r aid aname adesc _ <<< "$ach"
    if has_achievement "$aid"; then
      earned=$(( earned + 1 ))
      printf '  %s🏆 %s%s — %s%s\n' "$B_PURPLE" "$B_GREEN" "$aname" "$P_GREY" "$adesc" "$RESET"
    else
      printf '  %s🔒 %s%s — %s%s\n' "$P_GREY" "$P_GREY" "$aname" "$P_GREY" "$adesc" "$RESET"
    fi
  done
  hr "" "$TERM_W"
  printf '  %sProgress: %s%d/%d%s achievements earned.%s\n\n' \
    "$P_AMBER" "$P_GOLD" "$earned" "$total" "$P_AMBER" "$RESET"
  read -n 1 -s -r -p "  Press any key to return..."
}
