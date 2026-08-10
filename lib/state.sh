# ═══════════════════════════════════════════════════════════════════════════
# lib/state.sh — character state, save/load, inventory + achievement helpers
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_STATE:-}" ]] && return
declare -g _OLlama_RPG_STATE=1

# ─────────────────────────────────────────────────────────────────────────────
# CHARACTER STATE
#   CHAR is the single source of truth for the player's progression.
#   New in v2: achievements, inventory, encounters_seen, challenges_won.
# ─────────────────────────────────────────────────────────────────────────────

declare -gA CHAR=(
  [level]=1
  [xp]=0
  [hp]=100
  [hp_max]=100
  [mp]=50
  [mp_max]=50
  [gold]=0
  [model]=""
  [skills]=""            # comma-sep unlocked skill IDs
  [active_skills]=""     # comma-sep active skill IDs (subset of skills)
  [talents]=""           # comma-sep talent IDs
  [persona]="default"
  [system_prompt]="base"
  [prompts_sent]=0
  [tokens_received]=0
  [quests_completed]=0
  [streak]=1
  [last_login]=""
  [created]=""
  [talent_points]=0
  # ── v2 extensions ──
  [achievements]=""      # comma-sep achievement IDs earned
  [inventory]=""         # comma-sep "item_id:count"
  [encounters_seen]=0
  [challenges_won]=0
  [bosses_slain]=0
)

# Conversation log (ring buffer of roles/texts)
declare -ga MSG_ROLE=()
declare -ga MSG_TEXT=()

# Globals for last Ollama response
LAST_RESPONSE=""
LAST_TOKENS=0

# Terminal size
TERM_W=80
TERM_H=24

# ─────────────────────────────────────────────────────────────────────────────
# SAVE / LOAD
# ─────────────────────────────────────────────────────────────────────────────

# All keys persisted to the save file. Order is irrelevant for loading.
SAVE_KEYS=(
  level xp hp hp_max mp mp_max gold model
  skills active_skills talents persona system_prompt
  prompts_sent tokens_received quests_completed streak
  last_login created talent_points
  achievements inventory encounters_seen challenges_won bosses_slain
)

save_state() {
  {
    echo "# Ollama RPG save file"
    echo "# Version: $SCRIPT_VERSION"
    echo "# Last saved: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    for key in "${SAVE_KEYS[@]}"; do
      printf '%s=%s\n' "$key" "${CHAR[$key]:-}"
    done
  } > "$SAVE_FILE"
}

load_state() {
  if [[ ! -f "$SAVE_FILE" ]]; then
    return 1
  fi

  # Build a fast lookup of known keys
  local known=""
  for k in "${SAVE_KEYS[@]}"; do known+="|$k"; done
  known="${known}|"

  while IFS='=' read -r key val; do
    # Skip comments and empty lines
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    # Trim whitespace
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    # Only set known keys
    if [[ "$known" == *"|$key|"* ]]; then
      CHAR[$key]="$val"
    fi
  done < "$SAVE_FILE"

  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# INVENTORY HELPERS (v2)
# ─────────────────────────────────────────────────────────────────────────────

# Add N of an item to the inventory. item_id is validated by caller.
inv_add() {
  local id=$1 count=${2:-1}
  [[ -z "$id" ]] && return
  local IFS=','
  read -ra parts <<< "${CHAR[inventory]:-}"
  local found=0
  local new_inv=""
  for entry in "${parts[@]}"; do
    [[ -z "$entry" ]] && continue
    local eid=${entry%%:*} ecnt=${entry##*:}
    if [[ "$eid" == "$id" ]]; then
      ecnt=$(( ecnt + count ))
      found=1
    fi
    if [[ -n "$new_inv" ]]; then new_inv+=","; fi
    new_inv+="$eid:$ecnt"
  done
  if (( found == 0 )); then
    if [[ -n "$new_inv" ]]; then new_inv+=","; fi
    new_inv+="$id:$count"
  fi
  CHAR[inventory]="$new_inv"
}

# Remove 1 of an item. Returns 0 if removed, 1 if not present.
inv_remove_one() {
  local id=$1
  local IFS=','
  read -ra parts <<< "${CHAR[inventory]:-}"
  local new_inv=""
  local removed=0
  for entry in "${parts[@]}"; do
    [[ -z "$entry" ]] && continue
    local eid=${entry%%:*} ecnt=${entry##*:}
    if [[ "$eid" == "$id" && "$removed" -eq 0 ]]; then
      ecnt=$(( ecnt - 1 ))
      removed=1
      if (( ecnt > 0 )); then
        if [[ -n "$new_inv" ]]; then new_inv+=","; fi
        new_inv+="$eid:$ecnt"
      fi
      continue
    fi
    if [[ -n "$new_inv" ]]; then new_inv+=","; fi
    new_inv+="$entry"
  done
  CHAR[inventory]="$new_inv"
  return $(( 1 - removed ))
}

# Count of an item in inventory (0 if absent).
inv_count() {
  local id=$1
  local IFS=','
  read -ra parts <<< "${CHAR[inventory]:-}"
  for entry in "${parts[@]}"; do
    [[ -z "$entry" ]] && continue
    local eid=${entry%%:*} ecnt=${entry##*:}
    if [[ "$eid" == "$id" ]]; then
      echo "$ecnt"; return
    fi
  done
  echo 0
}

# ─────────────────────────────────────────────────────────────────────────────
# ACHIEVEMENT HELPER (v2)
# ─────────────────────────────────────────────────────────────────────────────

has_achievement() {
  local id=$1
  [[ ",${CHAR[achievements]}," == *",$id,"* ]]
}

grant_achievement() {
  local id=$1
  has_achievement "$id" && return 1
  if [[ -n "${CHAR[achievements]}" ]]; then
    CHAR[achievements]="${CHAR[achievements]},$id"
  else
    CHAR[achievements]="$id"
  fi
  return 0
}
