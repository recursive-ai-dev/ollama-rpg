# Audit — Ollama RPG

<!-- REGEN:START -->
## Scope & method
- commit: `9617ce6386385f79e44eb1afe19fc9afb727a0f7`
- date: `2026-09-07`
- languages: Bash
- LOC: ~3300
- files audited: 16
- tools run: shellcheck, bash
- model: claude-3-5-sonnet
- what was NOT covered: Deep logic chain validation, specific OS environment behaviors.

## Executive summary
The Ollama RPG codebase is a well-structured Bash-based terminal game, but it suffers from a major defect related to uninitialized array keys and `set -u` (unbound variable) protection. The game will crash reliably when character progression or status updates try to reference variables (like `hp_max`, `mp_max`, `hp`, `mp`, `talent_points`) before they are properly initialized because Bash throws an error on unbound variables with `set -u`. This is the single worst issue as it completely breaks normal gameplay upon levelling up or taking certain actions. There are also several minor format string bugs in `printf` statements across UI rendering scripts. The overall architecture is impressively modular for a Bash script.

## Findings by severity
| ID | Location | Category | Claim | Confidence |
|---|---|---|---|---|
| F001 | lib/progression.sh:72 | correctness | Variables are modified using undeclared or unassigned array keys causing crash under `set -u`. | confirmed |
| F002 | lib/screens.sh:131 | correctness | Undefined variable `hp` used in arithmetic operations on status screen causing crash under `set -u`. | confirmed |
| F003 | lib/screens.sh:190 | input-validation | Variable `cmd` is passed without quotes causing potential word splitting and globbing. | confirmed |
| F004 | lib/progression.sh:176 | correctness | `printf` format string mismatch: 3 format specifiers but 2 arguments. | confirmed |
| F005 | lib/progression.sh:177 | correctness | `printf` format string mismatch: 7 format specifiers but 8 arguments. | confirmed |
| F006 | lib/screens.sh:51 | correctness | `printf` format string mismatch: 3 format specifiers but 2 arguments. | confirmed |

## Systemic themes
- **Unbound Variables in Arithmetic:** The usage of associative arrays for character stats (e.g., `CHAR[hp_max]`) assumes they default to 0 in arithmetic operations, but under `set -u`, these fail with an error. This pattern exists in multiple files (`lib/progression.sh`, `lib/screens.sh`).
- **Format String Mismatches:** There are multiple `printf` statements in the UI logic where the number of format specifiers does not match the number of provided arguments, mostly related to ANSI color escape variables.

## Design opinions
- **Use of `set -u` in Bash Games:** While `set -u` is generally good practice for strictness, for a game state stored in an associative array, it might be more robust to write a small helper function to safely fetch stats (e.g., `get_stat "hp_max"`) which falls back to 0 if unset, rather than repeating `${CHAR[hp_max]:-0}` everywhere.

## Strengths
- `lib/ollama.sh:42`: "Stream and accumulate. Each line is a JSON object. Field extraction is done with json_field... not regex..." — The custom stream parsing and JSON field extraction using string manipulation without relying on external tools (like `jq`) is a clever and robust constraint adherence for zero dependencies.
- Modular architecture: The use of source guards (`[[ -n "${_OLlama_RPG_SCREENS:-}" ]] && return`) and structured components (screens, data, lore, tools) makes the 3000+ line project remarkably easy to navigate.

## Verification & limitations
- Findings confirmed: 6
- Plausible: 0
- Rejected: 1 (False positive related to while-read loop EOF behavior)
- Estimated false-positive risk: Low, since `shellcheck` identified the exact lines and `set -u` behavior was manually verified.
- Blind spots: Did not thoroughly test all random encounter branches or fully trace the tool usage interactions with the LLM API.
<!-- REGEN:END -->

## Findings Log

### F001 — [HIGH] lib/progression.sh:72 — Variables are modified using undeclared or unassigned array keys causing potential empty evaluations.
**Category:** correctness  **Confidence:** confirmed
**Code:**
```bash
CHAR[hp_max]=$(( ${CHAR[hp_max]} + 10 ))
```
**Trigger:** Calling progression level up code without hp_max set explicitly
**Impact:** Bash arithmetic treats empty values as 0, or throws an error if `set -u` is enabled. `set -u` is enabled in `ollama-rpg.sh`.
**Fix:** Initialize properly via `CHAR[hp_max]=${CHAR[hp_max]:-0}` before arithmetic or at creation.

### F002 — [HIGH] lib/screens.sh:131 — Undefined variable `hp` used in arithmetic operations on status screen.
**Category:** correctness  **Confidence:** confirmed
**Code:**
```bash
CHAR[hp]=$(( ${CHAR[hp]} + 20 ))
```
**Trigger:** Selecting HP boost in status screen before HP is explicitly initialized.
**Impact:** Crash due to `set -u`.
**Fix:** Initialize variables before arithmetic.

### F003 — [MEDIUM] lib/screens.sh:190 — Variable `cmd` is passed without quotes causing potential word splitting and globbing.
**Category:** input-validation  **Confidence:** confirmed
**Code:**
```bash
_skill_handle_command $cmd
```
**Trigger:** A skill action command containing spaces or glob characters is entered.
**Impact:** The arguments get split and interpreted incorrectly by `_skill_handle_command`.
**Fix:** Quote the variable: `_skill_handle_command "$cmd"`

### F004 — [MEDIUM] lib/progression.sh:176 — `printf` format string mismatch: 3 format specifiers but 2 arguments.
**Category:** correctness  **Confidence:** confirmed
**Code:**
```bash
printf '  %s%s╔══════════════════════════════════════════════════════════════╗%s\n' "$B_CYAN" "$RESET"
```
**Trigger:** Completing a quest triggers banner rendering.
**Impact:** Format string error during runtime, printing missing string or failing silently depending on bash version/implementation.
**Fix:** Provide the missing argument or fix the format string.

### F005 — [MEDIUM] lib/progression.sh:177 — `printf` format string mismatch: 7 format specifiers but 8 arguments.
**Category:** correctness  **Confidence:** confirmed
**Code:**
```bash
printf '  %s%s║%s%s   ⚔  QUEST COMPLETE!  ⚔   %-42s%s║%s\n' \
```
**Trigger:** Completing a quest triggers banner rendering.
**Impact:** Format string error during runtime.
**Fix:** Provide the missing argument or fix the format string.

### F006 — [MEDIUM] lib/screens.sh:51 — `printf` format string mismatch: 3 format specifiers but 2 arguments.
**Category:** correctness  **Confidence:** confirmed
**Code:**
```bash
printf '%s%s╔══════════════════════════════════════════════════════════════╗%s\n' "$B_GOLD" "$RESET"
```
**Trigger:** Rendering the status screen.
**Impact:** Format string error.
**Fix:** Provide the missing argument or fix the format string.
