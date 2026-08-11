# ═══════════════════════════════════════════════════════════════════════════
# lib/ollama.sh — Ollama REST API client (curl based)
# ═══════════════════════════════════════════════════════════════════════════

[[ -n "${_OLlama_RPG_OLLAMA:-}" ]] && return
declare -g _OLlama_RPG_OLLAMA=1

ollama_check() {
  curl -s --max-time 2 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1
}

# List installed model tags from /api/tags. The response is a single JSON
# line; walked field-by-field (regex greedy matching would only yield the
# last model).
ollama_list_models() {
  local resp
  resp=$(curl -s --max-time 5 "${OLLAMA_URL}/api/tags" 2>/dev/null)
  [[ -n "$resp" ]] || return 1

  local rest name
  rest="$resp"
  while [[ "$rest" == *'"name":"'* ]]; do
    rest="${rest#*\"name\":\"}"
    name="${rest%%\"*}"
    [[ -n "$name" ]] && printf '%s\n' "$name"
  done | sort -u
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

# Sentinel used to protect escaped backslashes during unescaping. Record
# separator (0x1E) cannot legally appear in model output.
_JSON_BSLASH_SENTINEL=$'\x1e'

# Unescape a JSON string value (read from stdin, escapes preserved, output raw).
# Order matters: backslash escapes are protected first so that sequences like
# \\n (backslash + 'n') are not mistaken for a newline escape.
json_unescape() {
  local s
  s=$(cat)
  s="${s//\\\\/$_JSON_BSLASH_SENTINEL}"
  s="${s//\\n/$'\n'}"
  s="${s//\\t/$'\t'}"
  s="${s//\\r/}"
  s="${s//\\\//\/}"
  s="${s//\\\"/\"}"
  s="${s//$_JSON_BSLASH_SENTINEL/\\}"
  printf '%s' "$s"
}

# Extract the value of a top-level JSON field from a single JSON line (stdin).
# String values are returned with escapes still embedded (pipe through
# json_unescape); numbers/booleans are returned verbatim. Returns 1 if the
# field is absent. Unlike regex parsing, this handles values containing
# arbitrary text such as '"done"', '"eval_count":99', braces, etc.
json_field() {
  local field="$1"
  local line
  IFS= read -r line || return 1
  [[ -z "$line" ]] && return 1

  local pat="\"${field}\":"
  local s="${line#*$pat}"
  [[ "$s" == "$line" ]] && return 1

  # Skip leading whitespace after the colon.
  s="${s#"${s%%[![:space:]]*}"}"

  if [[ "${s:0:1}" == '"' ]]; then
    s="${s:1}"
    local out=""
    local -i i=0 n=${#s}
    while (( i < n )); do
      local ch="${s:i:1}"
      if [[ "$ch" == '"' ]]; then
        printf '%s' "$out"
        return 0
      fi
      if [[ "$ch" == '\' ]]; then
        local nxt="${s:i+1:1}"
        if [[ "$nxt" == "u" ]]; then
          out+="${s:i:6}"; i=$(( i + 6 )); continue
        fi
        out+="${s:i:2}"; i=$(( i + 2 )); continue
      fi
      out+="$ch"; i=$(( i + 1 ))
    done
    printf '%s' "$out"
    return 0
  fi

  # Number or boolean: read until ',' or '}'.
  local out=""
  local -i i=0 n=${#s}
  while (( i < n )); do
    local ch="${s:i:1}"
    [[ "$ch" == ',' || "$ch" == '}' ]] && break
    out+="$ch"; i=$(( i + 1 ))
  done
  printf '%s' "$out"
  return 0
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

  # Stream and accumulate. Each line is a JSON object. Field extraction is
  # done with json_field (proper string scanning), not regex, so response
  # text containing '"done"', '"eval_count":..', braces, etc. cannot corrupt
  # the parse or the token count.
  # NOTE: printf must emit a trailing newline — read() in bash 5.3+ returns
  # failure on unterminated input, and the stream's final line may lack one.
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    # A non-streaming error object (e.g. unknown model) must not be silently
    # swallowed — surface it so the player sees why the wizard said nothing.
    local err
    err=$(printf '%s\n' "$line" | json_field "error" 2>/dev/null)
    if [[ -n "$err" ]]; then
      LAST_RESPONSE="[Ollama error] $err"
      printf '%s' "$LAST_RESPONSE"
      continue
    fi

    local chunk
    chunk=$(printf '%s\n' "$line" | json_field "response" 2>/dev/null) || continue
    if [[ -n "$chunk" ]]; then
      chunk=$(printf '%s\n' "$chunk" | json_unescape)
      LAST_RESPONSE+="$chunk"
      # Live print to terminal
      printf '%s' "$chunk"
    fi

    # Extract token count from the final ("done":true) line
    if [[ "$(printf '%s\n' "$line" | json_field "done" 2>/dev/null)" == "true" ]]; then
      local tokens
      tokens=$(printf '%s\n' "$line" | json_field "eval_count" 2>/dev/null)
      [[ -n "$tokens" && "$tokens" =~ ^[0-9]+$ ]] && LAST_TOKENS=$tokens
    fi
  done < <(curl -sN --max-time 600 "${OLLAMA_URL}/api/generate" -d "$payload" 2>/dev/null)
}
