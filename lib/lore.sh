# ═══════════════════════════════════════════════════════════════════════════
# lib/lore.sh — the world codex (v2 content expansion)
# ═══════════════════════════════════════════════════════════════════════════
#
# LORE format: id|title|text
# Brought to life by the /lore command, Torch of Clarity items, and the
# "Whisper of the Ancients" encounter.

[[ -n "${_OLlama_RPG_LORE:-}" ]] && return
declare -g _OLlama_RPG_LORE=1

declare -ga LORE=(
  "origin|The First Compile|Before the world was text, there was only the Great Void and a single blinking cursor. From it spoke the Compiler, who separated logic from chaos and named the languages. Thus was the Realm of Code born."
  "ollama|The Oracle of Ollama|Deep beneath the Citadel hums the Oracle, an engine of thought that answers all who ask with respect. Bind a Familiar (a model) to converse with its echo."
  "conclave|The Conclave|The Conclave is the gathering hall of apprentice and archmage alike. Here prompts are spoken, and the Wizard answers. Every word earns Experience — the currency of growth."
  "familiars|Familiars and Fools|Models are Familiars: mirrors that reflect your questions. A wise coder chooses their Familiar by temperament — some patient, some terse, some grand."
  "skills|The Grimoire|Skills are spells scribed into a Grimoire. Coding tools reshape your prompts; system prompts reshape the Wizard's mind; personas lend it a voice; shell tools reach into the mortal filesystem."
  "talents|Talents of Blood|Talents are gifts of lineage. Some hasten learning, some bend fortune, some mend the body after long debugging. Spend Talent Points wisely when you ascend."
  "bugs|The Bugs| Bugs are small hungry things born of missing logic. They bite HP and morale. Slay them with tests, refactors, and the Syntax Sentinel."
  "dragons|Code Dragons|In the deepest stacks dwell Code Dragons — legacy systems of terrible complexity. To slay one is the mark of a true Master. Beware their breath of technical debt."
  "encounters|Wanderers of the Stack|The Stack is alive with wanderers: Mana Springs, Gold Veins, Gremlins, and Whispering Ancients. Travel it often and fortune finds you."
  "streaks|The Daily Flame|A flame is kept in the Conclave for each coder who returns daily. Tend it; let it die and the streak resets, but rekindle it and bonuses flow."
  "archmages|The Archmages|Those who reach Level 20 are named Legend, and beyond that, Myth. Their code is said to compile itself. They rarely speak, but when they do, the realm listens."
  "items|Relics of the Realm|Potions, elixirs and scrolls are relics left by fallen adventurers. Keep them in your Satchel; a timely phoenix feather has saved many a midnight deploy."
)

# Print one random lore entry.
lore_random() {
  local pick=${LORE[$(( RANDOM % ${#LORE[@]} ))]}
  local lid ltitle ltext
  IFS='|' read -r lid ltitle ltext <<< "$pick"
  echo ""
  box_banner "$B_PURPLE" "📜 $ltitle" "$ltext"
  sleep 2
}

# Full codex browser.
lore_screen() {
  clear_screen
  printf '\n  %s%s⚔  CODEX OF THE REALM  ⚔%s\n\n' "$B_PURPLE" "$BOLD" "$RESET"

  hr "Sagas" "$TERM_W"
  local idx=1
  for entry in "${LORE[@]}"; do
    local lid ltitle ltext
    IFS='|' read -r lid ltitle ltext <<< "$entry"
    printf '  %s[%d]%s %s%s%s — %s\n' \
      "$P_GOLD" "$idx" "$RESET" "$B_GREEN" "$ltitle" "$RESET" "$P_GREY" "$ltext" "$RESET"
    ((idx++))
  done
  hr "" "$TERM_W"
  printf '  %sUse /lore <number> to read a saga in full.%s\n' "$P_GREEN" "$RESET"
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}

# Show a single lore entry by 1-based index (for /lore <n>).
lore_show() {
  local n=$1
  if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 1 || n > ${#LORE[@]} )); then
    printf '  %sNo such saga (%d).%s\n' "$P_RED" "$n" "$RESET"
    sleep 1
    return
  fi
  local entry="${LORE[$(( n - 1 ))]}"
  local lid ltitle ltext
  IFS='|' read -r lid ltitle ltext <<< "$entry"
  clear_screen
  box_banner "$B_PURPLE" "📜 $ltitle" "$ltext"
  echo ""
  read -n 1 -s -r -p "  Press any key to return..."
}
