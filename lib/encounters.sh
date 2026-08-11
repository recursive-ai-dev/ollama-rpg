# ═══════════════════════════════════════════════════════════════════════════
# lib/encounters.sh — random world encounters and item usage (v2)
# ═══════════════════════════════════════════════════════════════════════════
#
# ENCOUNTERS format: id|name|description|effect_type|effect_arg
#   effect_type: damage_hp | heal_hp | heal_mp | gold | item | lore | drain_mp
#   effect_arg : numeric amount | (empty for item/lore)

[[ -n "${_OLlama_RPG_ENCOUNTERS:-}" ]] && return
declare -g _OLlama_RPG_ENCOUNTERS=1

declare -ga ENCOUNTERS=(
  "wandering_bug|A Wandering Bug|An errant insect of logic nibbles your sanity.|damage_hp|15"
  "syntax_spider|Syntax Spider|It weaves a web of missing semicolons around you.|damage_hp|20"
  "mana_spring|Mana Spring|A cool spring of arcane water restores your mind.|heal_mp|25"
  "gold_vein|Glittering Gold Vein|You pry a few coins from a crack in the world.|gold|40"
  "treasure_chest|Forgotten Chest|A chest left by a previous adventurer.|item|"
  "wise_spirit|Wise Spirit|A gentle presence mends your wounds.|heal_hp|20"
  "lore_whisper|Whisper of the Ancients|The wind recalls a forgotten tale.|lore|"
  "mana_vampire|Mana Vampire|It drains your reserves as payment for secrets.|drain_mp|15"
  "lucky_clover|Four-Leaf Clover|Fortune favours the bold — a small boon.|heal_hp|10"
  "gremlin|Mischievous Gremlin|It tangles your variables but leaves a trinket.|item|"
)

# Apply a single encounter's effect to the character.
apply_encounter_effect() {
  local etype=$1 earg=$2
  case "$etype" in
    damage_hp)
      local dmg=$earg
      CHAR[hp]=$(( ${CHAR[hp]} - dmg ))
      (( ${CHAR[hp]} < 0 )) && CHAR[hp]=0
      printf '  %sYou take %d damage! HP now %d/%d%s\n' "$P_RED" "$dmg" "${CHAR[hp]}" "${CHAR[hp_max]}" "$RESET"
      ;;
    heal_hp)
      local heal=$earg
      CHAR[hp]=$(( ${CHAR[hp]} + heal ))
      (( ${CHAR[hp]} > ${CHAR[hp_max]} )) && CHAR[hp]=${CHAR[hp_max]}
      printf '  %sYou recover %d HP! HP now %d/%d%s\n' "$P_GREEN" "$heal" "${CHAR[hp]}" "${CHAR[hp_max]}" "$RESET"
      ;;
    heal_mp)
      local heal=$earg
      CHAR[mp]=$(( ${CHAR[mp]} + heal ))
      (( ${CHAR[mp]} > ${CHAR[mp_max]} )) && CHAR[mp]=${CHAR[mp_max]}
      printf '  %sYou recover %d MP! MP now %d/%d%s\n' "$P_CYAN" "$heal" "${CHAR[mp]}" "${CHAR[mp_max]}" "$RESET"
      ;;
    drain_mp)
      local drain=$earg
      CHAR[mp]=$(( ${CHAR[mp]} - drain ))
      (( ${CHAR[mp]} < 0 )) && CHAR[mp]=0
      printf '  %sYou lose %d MP! MP now %d/%d%s\n' "$P_BLUE" "$drain" "${CHAR[mp]}" "${CHAR[mp_max]}" "$RESET"
      ;;
    gold)
      local g=$earg
      CHAR[gold]=$(( ${CHAR[gold]} + g ))
      printf '  %sYou find %d gold!%s\n' "$P_GOLD" "$g" "$RESET"
      ;;
    item)
      local drop
      drop=$(roll_item_drop)
      if [[ -n "$drop" ]]; then
        inv_add "$drop" 1
        printf '  %sYou obtain: %s%s%s\n' "$B_PURPLE" "$B_GREEN" "$(item_field "$drop" name)" "$RESET"
      fi
      ;;
    lore)
      if declare -F lore_random >/dev/null; then
        lore_random
      fi
      ;;
  esac
}

# Maybe trigger a random encounter after a prompt. No-op if Ollama is down or
# the player is at 0 HP (don't kick a coder while they're down).
maybe_encounter() {
  local chance=$(( ENCOUNTER_CHANCE + $(talent_encounter_bonus) ))
  # Pack Rat slightly raises item-related encounters implicitly via drops.
  if (( RANDOM % 100 >= chance )); then
    return
  fi

  local eid ename edesc etype earg
  local generated=0
  # 35% of the time, let the wizard conjure a live world event. Any LLM
  # failure falls back to the scripted pool below.
  if (( RANDOM % 100 < 35 )) && declare -F gen_encounter >/dev/null; then
    if gen_encounter; then
      eid="gen_$RANDOM"
      ename="$GEN_NAME"
      edesc="$GEN_DESC"
      etype="$GEN_EFFECT"
      earg="$GEN_AMOUNT"
      generated=1
    fi
  fi
  if (( generated == 0 )); then
    local pick=${ENCOUNTERS[$(( RANDOM % ${#ENCOUNTERS[@]} ))]}
    IFS='|' read -r eid ename edesc etype earg <<< "$pick"
  fi

  echo ""
  box_banner "$B_PINK" "⚡ $ename ⚡" "$edesc"
  CHAR[encounters_seen]=$(( ${CHAR[encounters_seen]} + 1 ))
  apply_encounter_effect "$etype" "$earg"

  # Item drop chance is boosted by Pack Rat.
  if (( RANDOM % 100 < (10 + $(talent_packrat_bonus)) )) && [[ "$etype" != "item" ]]; then
    local drop
    drop=$(roll_item_drop)
    if [[ -n "$drop" ]]; then
      inv_add "$drop" 1
      printf '  %s%s✦ It also dropped: %s!%s\n' "$B_PURPLE" "$BOLD" "$(item_field "$drop" name)" "$RESET"
    fi
  fi

  check_achievements
  save_state
  sleep 2
}

# Use an item from the inventory by id.
use_item() {
  local id=$1
  [[ -z "$id" ]] && { printf '  %sUsage: /use <item_id>%s\n' "$P_RED" "$RESET"; sleep 1; return; }

  local cnt
  cnt=$(inv_count "$id")
  if (( cnt < 1 )); then
    printf '  %sYou do not have a %s.%s\n' "$P_RED" "$id" "$RESET"
    sleep 1
    return
  fi

  local iname itype iarg
  iname=$(item_field "$id" name 2>/dev/null || echo "$id")
  itype=$(item_field "$id" type 2>/dev/null || echo "unknown")
  iarg=$(item_field "$id" arg 2>/dev/null || echo "")

  echo ""
  box_banner "$B_PURPLE" "Using: $iname" "$(item_field "$id" desc 2>/dev/null || "")"

  # Apply barterer multiplier to restorative amounts.
  local mult
  mult=$(talent_item_mult)

  case "$itype" in
    heal_hp)
      local amt=$(( iarg * mult / 100 ))
      CHAR[hp]=$(( ${CHAR[hp]} + amt ))
      (( ${CHAR[hp]} > ${CHAR[hp_max]} )) && CHAR[hp]=${CHAR[hp_max]}
      printf '  %s%s+%d HP%s (now %d/%d)%s\n' "$P_GREEN" "$BOLD" "$amt" "$RESET" "${CHAR[hp]}" "${CHAR[hp_max]}" "$RESET"
      ;;
    heal_mp)
      local amt=$(( iarg * mult / 100 ))
      CHAR[mp]=$(( ${CHAR[mp]} + amt ))
      (( ${CHAR[mp]} > ${CHAR[mp_max]} )) && CHAR[mp]=${CHAR[mp_max]}
      printf '  %s%s+%d MP%s (now %d/%d)%s\n' "$P_CYAN" "$BOLD" "$amt" "$RESET" "${CHAR[mp]}" "${CHAR[mp_max]}" "$RESET"
      ;;
    heal_both)
      local hp_amt mp_amt
      hp_amt=${iarg%%,*}; mp_amt=${iarg##*,}
      hp_amt=$(( hp_amt * mult / 100 )); mp_amt=$(( mp_amt * mult / 100 ))
      CHAR[hp]=$(( ${CHAR[hp]} + hp_amt ))
      CHAR[mp]=$(( ${CHAR[mp]} + mp_amt ))
      (( ${CHAR[hp]} > ${CHAR[hp_max]} )) && CHAR[hp]=${CHAR[hp_max]}
      (( ${CHAR[mp]} > ${CHAR[mp_max]} )) && CHAR[mp]=${CHAR[mp_max]}
      printf '  %s%s+%d HP, +%d MP%s\n' "$P_GREEN" "$BOLD" "$hp_amt" "$mp_amt" "$RESET"
      ;;
    scroll_xp)
      printf '  %s%s+%d XP from insight!%s\n' "$P_GOLD" "$BOLD" "$iarg" "$RESET"
      inv_remove_one "$id"
      save_state
      apply_xp "$iarg"
      return
      ;;
    reveal)
      if declare -F lore_random >/dev/null; then
        lore_random
      fi
      ;;
    *)
      printf '  %sThat item cannot be used.%s\n' "$P_GREY" "$RESET"
      sleep 1
      return
      ;;
  esac

  # Blood Mage: when starved of MP, convert HP to MP.
  if has_talent "blood_mage" && (( ${CHAR[mp]} < 5 )) && (( ${CHAR[hp]} > 10 )); then
    CHAR[hp]=$(( ${CHAR[hp]} - 10 ))
    CHAR[mp]=$(( ${CHAR[mp]} + 20 ))
    printf '  %s%s🩸 Blood Mage: converted 10 HP into 20 MP.%s\n' "$B_RED" "$BOLD" "$RESET"
  fi

  inv_remove_one "$id"
  check_achievements
  save_state
  sleep 1
}
