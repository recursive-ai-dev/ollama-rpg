# ═══════════════════════════════════════════════════════════════════════════
# lib/effects.sh — content field accessors, prompt/effect computation,
#                  and talent hook helpers
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_EFFECTS:-}" ]] && return
declare -g _OLlama_RPG_EFFECTS=1

# ── Generic field accessors ─────────────────────────────────────────────────

skill_field() {
  local id=$1 field=$2
  for skill in "${SKILLS[@]}"; do
    local fields
    IFS='|' read -ra fields <<< "$skill"
    if [[ "${fields[0]}" == "$id" ]]; then
      case $field in
        id)   echo "${fields[0]}" ;;
        name) echo "${fields[1]}" ;;
        cat)  echo "${fields[2]}" ;;
        desc) echo "${fields[3]}" ;;
        lvl)  echo "${fields[4]}" ;;
        type) echo "${fields[5]}" ;;
        arg)  echo "${fields[6]}" ;;
      esac
      return 0
    fi
  done
  return 1
}

talent_field() {
  local id=$1 field=$2
  for talent in "${TALENTS[@]}"; do
    local fields
    IFS='|' read -ra fields <<< "$talent"
    if [[ "${fields[0]}" == "$id" ]]; then
      case $field in
        id)   echo "${fields[0]}" ;;
        name) echo "${fields[1]}" ;;
        desc) echo "${fields[2]}" ;;
        lvl)  echo "${fields[3]}" ;;
      esac
      return 0
    fi
  done
  return 1
}

item_field() {
  local id=$1 field=$2
  for item in "${ITEMS[@]}"; do
    local fields
    IFS='|' read -ra fields <<< "$item"
    if [[ "${fields[0]}" == "$id" ]]; then
      case $field in
        id)       echo "${fields[0]}" ;;
        name)     echo "${fields[1]}" ;;
        desc)     echo "${fields[2]}" ;;
        type)     echo "${fields[3]}" ;;
        arg)      echo "${fields[4]}" ;;
        rarity)   echo "${fields[5]}" ;;
      esac
      return 0
    fi
  done
  return 1
}

achievement_field() {
  local id=$1 field=$2
  for ach in "${ACHIEVEMENTS[@]}"; do
    local fields
    IFS='|' read -ra fields <<< "$ach"
    if [[ "${fields[0]}" == "$id" ]]; then
      case $field in
        id)   echo "${fields[0]}" ;;
        name) echo "${fields[1]}" ;;
        desc) echo "${fields[2]}" ;;
        gtype) echo "${fields[3]%%:*}" ;;
        gval)  echo "${fields[3]##*:}" ;;
      esac
      return 0
    fi
  done
  return 1
}

# ── Prompt/system prompt composition ────────────────────────────────────────

compute_system_prompt() {
  local sys=""

  if [[ "${CHAR[system_prompt]}" != "base" ]]; then
    local type
    type=$(skill_field "${CHAR[system_prompt]}" type)
    if [[ "$type" == "system" ]]; then
      sys=$(skill_field "${CHAR[system_prompt]}" arg)
    fi
  fi

  if [[ "${CHAR[persona]}" != "default" ]]; then
    local type
    type=$(skill_field "${CHAR[persona]}" type)
    if [[ "$type" == "persona" ]]; then
      local persona_arg
      persona_arg=$(skill_field "${CHAR[persona]}" arg)
      if [[ -n "$sys" ]]; then
        sys="$sys

$persona_arg"
      else
        sys="$persona_arg"
      fi
    fi
  fi

  if [[ ",${CHAR[talents]}," == *",mentor_bond,"* ]]; then
    if [[ -n "$sys" ]]; then
      sys="$sys

Format your response with clear sections, headers, and code blocks where appropriate."
    else
      sys="Format your response with clear sections, headers, and code blocks where appropriate."
    fi
  fi

  printf '%s' "$sys"
}

compute_prompt_prefix() {
  local prefix=""

  if [[ -z "${CHAR[active_skills]:-}" ]]; then
    printf ''
    return
  fi

  local IFS=','
  read -ra active <<< "${CHAR[active_skills]}"
  unset IFS

  for active_id in "${active[@]}"; do
    [[ -z "$active_id" ]] && continue
    local type
    type=$(skill_field "$active_id" type 2>/dev/null) || continue
    if [[ "$type" == "prefix" ]]; then
      local arg
      arg=$(skill_field "$active_id" arg)
      if [[ -n "$prefix" ]]; then
        prefix="$prefix

$arg"
      else
        prefix="$arg"
      fi
    fi
  done

  printf '%s' "$prefix"
}

# ── Talent hook helpers (centralised so new talents are easy to add) ─────────

# Percent chance (0-100) that a Lucky Charm triggers on XP gain.
talent_lucky_chance() {
  if [[ ",${CHAR[talents]}," == *",gambler,"* ]]; then
    echo 20
  else
    echo 10
  fi
}

# HP regenerated after each prompt (0 if none).
talent_regen_hp() {
  if [[ ",${CHAR[talents]}," == *",healer,"* ]]; then
    echo 5
  else
    echo 0
  fi
}

# Extra percent chance added to random encounters.
talent_encounter_bonus() {
  if [[ ",${CHAR[talents]}," == *",quickened,"* ]]; then
    echo 5
  else
    echo 0
  fi
}

# Multiplier applied to item restoration amounts (barterer).
talent_item_mult() {
  if [[ ",${CHAR[talents]}," == *",barterer,"* ]]; then
    echo 125
  else
    echo 100
  fi
}

# Extra percent chance that an encounter yields an item drop.
talent_packrat_bonus() {
  if [[ ",${CHAR[talents]}," == *",pack_rat,"* ]]; then
    echo 50
  else
    echo 0
  fi
}

# Is the given talent owned?
has_talent() {
  [[ ",${CHAR[talents]}," == *",$1,"* ]]
}
