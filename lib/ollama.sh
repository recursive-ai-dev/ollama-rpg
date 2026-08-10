# ═══════════════════════════════════════════════════════════════════════════
# lib/ollama.sh — Ollama REST API client (curl based)
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_OLLAMA:-}" ]] && return
declare -g _OLlama_RPG_OLLAMA=1

ollama_check() {
  curl -s --max-time 2 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1
}

ollama_list_models() {
  local resp
  resp=$(curl -s --max-time 5 "${OLLAMA_URL}/api/tags" 2>/dev/null)
  printf '%s' "$resp" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | sort -u
}

# JSON-escape a string (read from stdin, output escaped, no surrounding quotes)
json_escape() {
  local s
  s=$(cat)
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Stream chat with Ollama /api/generate endpoint.
# Sets globals: LAST_RESPONSE, LAST_TOKENS
ollama_chat() {
  local model="$1"
  local system="$2"
  local prompt="$3"

  local sys_json=""
  if [[ -n "$system" ]]; then
    sys_json="\"system\":\"$(printf '%s' "$system" | json_escape)\","
  fi

  local payload
  payload="{\"model\":\"${model}\",${sys_json}\"prompt\":\"$(printf '%s' "$prompt" | json_escape)\",\"stream\":true}"

  LAST_RESPONSE=""
  LAST_TOKENS=0

  # Stream and accumulate. Each line is a JSON object.
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Extract response chunk — between "response":" and the closing of that field.
    local chunk
    chunk=$(printf '%s' "$line" | sed -n 's/.*"response":"\(.*\)","done".*/\1/p')

    if [[ -n "$chunk" ]]; then
      # Unescape JSON string
      chunk="${chunk//\\n/$'\n'}"
      chunk="${chunk//\\t/$'\t'}"
      chunk="${chunk//\\\"/\"}"
      chunk="${chunk//\\\\/\\}"
      chunk="${chunk//\\r/}"

      LAST_RESPONSE+="$chunk"
      # Live print to terminal
      printf '%s' "$chunk"
    fi

    # Extract token count from final line
    if [[ "$line" == *'"done":true'* ]]; then
      local tokens
      tokens=$(printf '%s' "$line" | sed -n 's/.*"eval_count":\([0-9]*\).*/\1/p')
      [[ -n "$tokens" && "$tokens" =~ ^[0-9]+$ ]] && LAST_TOKENS=$tokens
    fi
  done < <(curl -sN --max-time 600 "${OLLAMA_URL}/api/generate" -d "$payload" 2>/dev/null)
}
