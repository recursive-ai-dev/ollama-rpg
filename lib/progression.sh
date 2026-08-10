# ═══════════════════════════════════════════════════════════════════════════
# lib/progression.sh — XP, leveling, quests and achievements
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_PROGRESSION:-}" ]] && return
declare -g _OLlama_RPG_PROGRESSION=1

# XP to go from level L to L+1: 50 * L * (L+1)
xp_for_level() {
  local lvl=$1
  echo $(( 50 * lvl * (lvl + 1) ))
}

# Class title by level
class_title() {
  local lvl=$1
  case $lvl in
    1)        echo "Apprentice" ;;
    2)        echo "Novice" ;;
    3)        echo "Adept" ;;
    [45])     echo "Journeyman" ;;
    [67])     echo "Expert" ;;
    [89])     echo "Veteran" ;;
    1[0-2])   echo "Master" ;;
    1[3-5])   echo "Grandmaster" ;;
    1[6-9])   echo "Archmage" ;;
    2[0-9]|3[0-9]) echo "Legend" ;;
    *)        echo "Myth" ;;
  esac
}

# Total number of items currently held (sum of inventory counts).
total_items() {
  local IFS=','
  read -ra parts <<< "${CHAR[inventory]:-}"
  local total=0
  for entry in "${parts[@]}"; do
    [[ -z "$entry" ]] && continue
    total=$(( total + ${entry##*:} ))
  done
  echo "$total"
}

# Current value of a progression metric used by quests/achievements.
metric_value() {
  case "$1" in
    prompts_sent|prompts) echo "${CHAR[prompts_sent]}" ;;
    tokens)               echo "${CHAR[tokens_received]}" ;;
    level)                echo "${CHAR[level]}" ;;
    streak)               echo "${CHAR[streak]}" ;;
    gold)                 echo "${CHAR[gold]}" ;;
    challenges)           echo "${CHAR[challenges_won]}" ;;
    bosses)               echo "${CHAR[bosses_slain]}" ;;
    items)                total_items ;;
    lucky)                has_achievement "fortunes_favour" && echo 1 || echo 0 ;;
    talent)               has_talent "$2" && echo 1 || echo 0 ;;
    *)                    echo 0 ;;
  esac
}

# Perform level-up while enough XP is banked. Calls the level-up animation and
# talent chooser (defined in lib/screens.sh) at runtime.
level_up_check() {
  while true; do
    local current_level=${CHAR[level]}
    local needed
    needed=$(xp_for_level "$current_level")

    if (( ${CHAR[xp]} >= needed )); then
      CHAR[level]=$(( current_level + 1 ))
      CHAR[xp]=$(( ${CHAR[xp]} - needed ))
      CHAR[hp_max]=$(( ${CHAR[hp_max]} + 10 ))
      CHAR[mp_max]=$(( ${CHAR[mp_max]} + 5 ))
      CHAR[hp]=${CHAR[hp_max]}
      CHAR[mp]=${CHAR[mp_max]}
      CHAR[gold]=$(( ${CHAR[gold]} + 20 * ${CHAR[level]} ))
      CHAR[talent_points]=$(( ${CHAR[talent_points]} + 1 ))

      if has_talent "scholar"; then
        CHAR[talent_points]=$(( ${CHAR[talent_points]} + 1 ))
      fi

      level_up_animation
      talent_chooser
    else
      break
    fi
  done
}

# Award XP (already modified by talents) and resolve all downstream progress.
apply_xp() {
  local amount=$1

  # Fast Learner talent: +25% XP
  if has_talent "fast_learner"; then
    amount=$(( amount * 5 / 4 ))
  fi

  # Lucky Charm (chance scales with Gambler's Edge)
  if has_talent "lucky"; then
    if (( RANDOM % 100 < $(talent_lucky_chance) )); then
      amount=$(( amount * 2 ))
      echo ""
      printf '%s%s✦ Lucky charm! XP doubled!%s\n' "$P_GOLD" "$BOLD" "$RESET"
      grant_achievement "fortunes_favour"
    fi
  fi

  CHAR[xp]=$(( ${CHAR[xp]} + amount ))

  level_up_check
  check_quests
  check_achievements
  save_state
}

# Catch-up function for achievements that may already be satisfied (used at
# boot and after each meaningful event).
check_achievements() {
  local changed=0
  for ach in "${ACHIEVEMENTS[@]}"; do
    local aid aname adesc goal gtype gval
    IFS='|' read -r aid aname adesc goal <<< "$ach"
    gtype="${goal%%:*}"
    gval="${goal##*:}"
    has_achievement "$aid" && continue

    local cur=0
    if [[ "$gtype" == "talent" ]]; then
      cur=$(metric_value "talent" "$gval")
    else
      cur=$(metric_value "$gtype")
    fi

    local threshold=$gval
    [[ "$gtype" == "talent" ]] && threshold=1

    if (( cur >= threshold )); then
      if grant_achievement "$aid"; then
        local aname
        aname=$(achievement_field "$aid" name)
        echo ""
        printf '  %s%s🏆 ACHIEVEMENT UNLOCKED: %s!%s\n' "$B_PURPLE" "$BOLD" "$aname" "$RESET"
        changed=1
      fi
    fi
  done
  (( changed )) && save_state
}

# Evaluate quest goals and award rewards on completion.
check_quests() {
  for quest in "${QUESTS[@]}"; do
    local qid qname qdesc qgoal qxp qgold
    IFS='|' read -r qid qname qdesc qgoal qxp qgold <<< "$quest"

    # Skip if already completed
    [[ ",${CHAR[quests_completed]}," == *",$qid,"* ]] && continue

    local goal_type goal_val
    goal_type="${qgoal%%:*}"
    goal_val="${qgoal##*:}"

    local current
    current=$(metric_value "$goal_type")

    if (( current >= goal_val )); then
      if [[ -n "${CHAR[quests_completed]}" ]]; then
        CHAR[quests_completed]="${CHAR[quests_completed]},$qid"
      else
        CHAR[quests_completed]="$qid"
      fi

      echo ""
      printf '  %s%s╔══════════════════════════════════════════════════════════════╗%s\n' "$B_CYAN" "$RESET"
      printf '  %s%s║%s%s   ⚔  QUEST COMPLETE!  ⚔   %-42s%s║%s\n' \
        "$B_CYAN" "$RESET" "$P_CYAN" "$BOLD" "$qname" "$P_CYAN" "$B_CYAN" "$RESET"
      printf '  %s%s║%s%s   %s                                              %s%s║%s\n' \
        "$B_CYAN" "$RESET" "$P_GREEN" "$RESET" "$qdesc" "$P_CYAN" "$B_CYAN" "$RESET"
      printf '  %s%s║%s%s   Reward: %d XP, %d gold                          %s%s║%s\n' \
        "$B_CYAN" "$RESET" "$P_GOLD" "$BOLD" "$qxp" "$qgold" "$P_CYAN" "$B_CYAN" "$RESET"
      printf '  %s%s╚══════════════════════════════════════════════════════════════╝%s\n' "$B_CYAN" "$RESET"
      echo ""

      # Award rewards (bypass talent XP modifiers for quest XP)
      CHAR[xp]=$(( ${CHAR[xp]} + qxp ))
      CHAR[gold]=$(( ${CHAR[gold]} + qgold ))

      # Small chance of a bonus item drop on quest completion.
      if (( RANDOM % 100 < 25 )); then
        local drop
        drop=$(roll_item_drop)
        if [[ -n "$drop" ]]; then
          inv_add "$drop" 1
          printf '  %s%s✦ Bonus drop: %s!%s\n' "$B_PURPLE" "$BOLD" "$(item_field "$drop" name)" "$RESET"
        fi
      fi

      level_up_check
      check_achievements
      sleep 2
    fi
  done
}
