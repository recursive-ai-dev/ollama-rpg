# ═══════════════════════════════════════════════════════════════════════════
# lib/gen.sh — LLM-generated content (quests, encounters) via strict JSON
# ═══════════════════════════════════════════════════════════════════════════
#
# The model is asked to emit a single JSON object. Output is decoded with the
# same json_field/json_unescape machinery as the chat stream, then VALIDATED
# and clamped before it touches game state. Any parse/validation failure
# falls back to the scripted content pools — the wizard never crashes.
#
# Sourced after lib/ollama.sh (depends on json_escape, json_field,
# json_unescape, ollama_check).

[[ -n "${_OLlama_RPG_GEN:-}" ]] && return
declare -g _OLlama_RPG_GEN=1

# Non-streaming request: echo the decoded response text; 1 on any failure.
llm_json() {
  local system="$1" prompt="$2"
  local sys_json=""
  if [[ -n "$system" ]]; then
    sys_json="\"system\":\"$(printf '%s' "$system" | json_escape)\","
  fi
  local payload
  payload="{\"model\":\"${CHAR[model]}\",${sys_json}\"prompt\":\"$(printf '%s' "$prompt" | json_escape)\",\"stream\":false}"

  local resp response
  resp=$(curl -s --max-time 120 "${OLLAMA_URL}/api/generate" -d "$payload" 2>/dev/null) || return 1
  [[ -n "$resp" ]] || return 1
  response=$(printf '%s\n' "$resp" | json_field "response") || return 1
  response=$(printf '%s\n' "$response" | json_unescape)
  printf '%s' "$response"
}

# Strip markdown code fences, collapse to one line (so json_field's
# single-line scan works), then keep ONLY the last brace-delimited region —
# thinking models narrate before/after the actual JSON object.
clean_json_text() {
  local s
  s=$(cat)
  s=$(printf '%s' "$s" | tr -d '\n')
  # Keep only the LAST brace-delimited object (thinking models narrate first).
  s=$(printf '%s' "$s" | grep -o '{[^}]*}' | tail -1)
  printf '%s' "$s"
}

# Integer sanity bounds used by both generators.
int_in_range() {
  local v=$1 lo=$2 hi=$3
  [[ "$v" =~ ^[0-9]+$ ]] && (( v >= lo && v <= hi ))
}

# ─────────────────────────────────────────────────────────────────────────────
# GENERATED QUESTS
#   Schema: {"id":"q_...","name":"...","desc":"...","goal":"prompts",
#            "goal_val":15,"xp":120,"gold":40}
#   goal one of: prompts | tokens | gold | challenges | bosses | streak | items
# ─────────────────────────────────────────────────────────────────────────────

declare -gA GEN_QUEST_GOALS=(
  [prompts]="prompts_sent"
  [tokens]="tokens"
  [gold]="gold"
  [challenges]="challenges"
  [bosses]="bosses"
  [streak]="streak"
  [items]="items"
)

gen_quest() {
  if ! ollama_check; then
    printf '  %sThe oracle is silent — Ollama is unreachable.%s\n' "$P_RED" "$RESET"
    sleep 1
    return 1
  fi

  local sys="You are the Quest Oracle of a fantasy coding RPG. The player is
a coder of level ${CHAR[level]} who earns XP by chatting with an AI mentor,
coding, and defeating code-themed challenges. You write short, flavourful
quests that fit their level and are achievable within a session.

Respond with ONLY a single JSON object. No markdown, no commentary, no code
fences. The object must use exactly these keys:
- \"id\": a short unique id matching ^[A-Za-z0-9_]+$
- \"name\": quest title, max 40 characters
- \"desc\": one sentence of flavour, max 120 characters
- \"goal\": one of prompts, tokens, gold, challenges, bosses, streak, items
- \"goal_val\": a positive integer goal for that metric (1 to 500)
- \"xp\": reward XP, integer 20 to 300
- \"gold\": reward gold, integer 0 to 200

Example:
{\"id\":\"q_git_mastery\",\"name\":\"Deep in the Reflog\",\"desc\":\"Consult the Wizard 10 times about version control.\",\"goal\":\"prompts\",\"goal_val\":10,\"xp\":90,\"gold\":30}"

  local prompt="Write one new quest for a level ${CHAR[level]} coding adventurer. Use the exact JSON schema."

  printf '  %s✦ The Oracle consults the arcane currents...%s' "$P_DIM_GREEN" "$RESET"
  local raw
  raw=$(llm_json "$sys" "$prompt") || {
    printf ' %s✗ the vision fades (no response).%s\n' "$P_RED" "$RESET"
    sleep 1
    return 1
  }
  raw=$(printf '%s' "$raw" | clean_json_text)
  printf ' %s✓%s\n' "$P_GREEN" "$RESET"

  local name desc goal goal_val xp gold id
  name=$(printf '%s\n' "$raw" | json_field "name" 2>/dev/null)
  desc=$(printf '%s\n' "$raw" | json_field "desc" 2>/dev/null)
  goal=$(printf '%s\n' "$raw" | json_field "goal" 2>/dev/null)
  goal_val=$(printf '%s\n' "$raw" | json_field "goal_val" 2>/dev/null)
  xp=$(printf '%s\n' "$raw" | json_field "xp" 2>/dev/null)
  gold=$(printf '%s\n' "$raw" | json_field "gold" 2>/dev/null)
  id=$(printf '%s\n' "$raw" | json_field "id" 2>/dev/null)

  # Validate everything; any problem → polite refusal.
  [[ -n "$name" && ${#name} -le 40 ]] || name=""
  [[ -n "$desc" && ${#desc} -le 120 ]] || desc=""
  [[ -n "${GEN_QUEST_GOALS[$goal]:-}" ]] || goal=""
  int_in_range "$goal_val" 1 500 || goal_val=""
  int_in_range "$xp" 20 300 || xp=""
  int_in_range "$gold" 0 200 || gold=""
  [[ "$id" =~ ^[A-Za-z0-9_]+$ ]] || id="q_$(date +%s)_$RANDOM"

  if [[ -z "$name" || -z "$desc" || -z "$goal" || -z "$goal_val" || -z "$xp" ]]; then
    printf '  %sThe Oracle mumbles something about "proper scrolls". (malformed JSON)%s\n' "$P_AMBER" "$RESET"
    sleep 1
    return 1
  fi

  QUESTS+=("$id|$name|$desc|${GEN_QUEST_GOALS[$goal]}:$goal_val|$xp|$gold")
  echo ""
  box_banner "$B_CYAN" "✦ NEW QUEST FROM THE ORACLE ✦" \
    "  $name" \
    "  $desc" \
    "  Goal: ${goal_val} ${goal}   Reward: ${xp} XP, ${gold} gold"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# GENERATED ENCOUNTERS
#   Schema: {"name":"...","desc":"...","effect_type":"gold|heal_hp|heal_mp|
#            damage_hp|drain_mp","amount":N}
#   Sets GEN_NAME/GEN_DESC/GEN_EFFECT/GEN_AMOUNT on success.
# ─────────────────────────────────────────────────────────────────────────────

gen_encounter() {
  local sys="You are a flavour writer for a fantasy coding RPG played in a
terminal. Write one short random world event for a coding adventurer.
Respond with ONLY a single JSON object. No markdown, no commentary.
Keys:
- \"name\": event title, max 30 characters
- \"desc\": one sentence, max 110 characters
- \"effect_type\": one of gold, heal_hp, heal_mp, damage_hp, drain_mp
- \"amount\": an integer for that effect
  (gold 10-80, heal_hp 5-30, heal_mp 5-25, damage_hp 5-25, drain_mp 5-20)

Example:
{\"name\":\"Compiler Frost\",\"desc\":\"A sudden chill freezes your terminal; a hidden linter whispers corrections.\",\"effect_type\":\"heal_hp\",\"amount\":15}"

  local prompt="Write one random world event for the adventurer. Use the exact JSON schema."
  local raw
  raw=$(llm_json "$sys" "$prompt") || return 1
  raw=$(printf '%s' "$raw" | clean_json_text)

  local name desc etype amount
  name=$(printf '%s\n' "$raw" | json_field "name" 2>/dev/null)
  desc=$(printf '%s\n' "$raw" | json_field "desc" 2>/dev/null)
  etype=$(printf '%s\n' "$raw" | json_field "effect_type" 2>/dev/null)
  amount=$(printf '%s\n' "$raw" | json_field "amount" 2>/dev/null)

  [[ -n "$name" && ${#name} -le 30 ]] || return 1
  [[ -n "$desc" && ${#desc} -le 110 ]] || return 1

  # Clamp the amount to the per-type safe band so a hallucinating model can
  # never one-shot the player or print absurd numbers.
  local lo=5 hi=30
  case "$etype" in
    gold)      lo=10; hi=80 ;;
    heal_hp)   lo=5;  hi=30 ;;
    heal_mp)   lo=5;  hi=25 ;;
    damage_hp) lo=5;  hi=25 ;;
    drain_mp)  lo=5;  hi=20 ;;
    *)         return 1 ;;
  esac
  int_in_range "$amount" "$lo" "$hi" || amount=$(( lo + RANDOM % (hi - lo + 1) ))

  GEN_NAME="$name"
  GEN_DESC="$desc"
  GEN_EFFECT="$etype"
  GEN_AMOUNT="$amount"
  return 0
}
