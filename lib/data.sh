# ═══════════════════════════════════════════════════════════════════════════
# lib/data.sh — game content: skills, talents, quests, achievements, items
# ═══════════════════════════════════════════════════════════════════════════
#
# Everything that defines "what the game contains" lives here so it is easy
# to extend. Formats:
#   SKILLS     id|name|category|description|unlock_level|effect_type|effect_arg
#              effect_type: prefix | system | persona | tool
#   TALENTS    id|name|description|unlock_level
#   QUESTS     id|name|description|goal|reward_xp|reward_gold
#              goal: prompts:N | tokens:N | level:N | streak:N | challenges:N |
#                    bosses:N | items:N
#   ACHIEVEMENTS id|name|description|goal_type|goal_val
#              goal_type: level|prompts|tokens|streak|gold|challenges|bosses|
#                         items|lucky|talent
#   ITEMS      id|name|description|type|effect_arg|rarity
#              type: heal_hp|heal_mp|heal_both|scroll_xp|reveal

[[ -n "${_OLlama_RPG_DATA:-}" ]] && return
declare -g _OLlama_RPG_DATA=1

# ─────────────────────────────────────────────────────────────────────────────
# SKILL DEFINITIONS
# ─────────────────────────────────────────────────────────────────────────────

declare -ga SKILLS=(
  # ── Coding tools (prefix) ──────────────────────────────────────────────
  "format_code|Code Formatter|coding|Auto-requests properly indented code|1|prefix|Please format any code in your response with proper, consistent indentation."
  "syntax_check|Syntax Sentinel|coding|Adds syntax-error check to prompts|1|prefix|Identify any syntax errors in the code and explain them."
  "refactor|Refactor's Eye|coding|Asks for refactored version of code|2|prefix|Provide a refactored, cleaner version with explanations of changes."
  "explain|Sage's Explanation|coding|Requests line-by-line explanation|2|prefix|Explain each line of code briefly."
  "test_writer|Test Smith|coding|Requests unit tests for the code|3|prefix|Write unit tests covering the main edge cases and explain what each verifies."
  "doc_writer|Lore Scribe|coding|Requests docstrings and comments|3|prefix|Add clear docstrings and inline comments explaining intent."
  "typed|Type Oracle|coding|Requests precise type annotations|4|prefix|Add precise type annotations and explain the type choices."
  "perf_tuner|Performance Tuner|coding|Requests performance optimizations|5|prefix|Suggest concrete performance optimizations with reasoning about complexity."
  "security|Ward of Security|coding|Requests a security review|6|prefix|Point out security vulnerabilities (injection, auth, secrets) and how to fix them."
  # ── System prompts ─────────────────────────────────────────────────────
  "mentor|Wise Mentor|prompt|Patient mentor who explains trade-offs|2|system|You are a wise, patient mentor. Explain trade-offs and reasoning. Use analogies when helpful."
  "architect|Guild Architect|prompt|Senior software architect|4|system|You are a senior software architect. Focus on system design, patterns, scalability, and long-term maintainability."
  "debugger|Bug Hunter|prompt|Focused debugger|3|system|You are a focused debugger. Identify root causes precisely. Propose minimal fixes."
  "socratic|Socratic Sage|prompt|Asks questions to lead you to answers|5|system|You are a Socratic sage. Ask guiding questions rather than giving direct answers. Lead the learner to discovery."
  "grandmaster|Grandmaster Dev|prompt|Ancient master coder|8|system|You are a grandmaster developer with decades of experience. Share deep wisdom, edge cases, and historical context."
  "security_audit|Security Auditor|prompt|Hardened security reviewer|7|system|You are a security auditor. Hunt vulnerabilities: injection, auth bypass, secrets leakage. Show minimal, safe fixes."
  "devops|Guild DevOps|prompt|Ops and deployment focus|6|system|You are a DevOps engineer. Focus on CI/CD, containers, observability, reliability and incident response."
  "data|Data Whisperer|prompt|Data and ML engineering focus|6|system|You are a data/ML engineer. Focus on pipelines, modeling, evaluation, and data quality."
  "rubber|Rubber Duck|prompt|Minimal prompting partner|4|system|You are a rubber duck. Stay mostly silent; ask exactly one sharp question to help them think."
  # ── Shell utilities (tool) ──────────────────────────────────────────────
  "snippet_library|Snippet Grimoire|shell|Browse saved code snippets|1|tool|snippet"
  "file_browser|Tome Browser|shell|Quick file viewer|2|tool|file"
  "history|Memory Crystal|shell|Recall past conversation|1|tool|history"
  "diff_view|Diff Crystal|shell|View file diffs|4|tool|diff"
  "clear_log|Clear Mind|shell|Clear conversation log (keeps XP)|1|tool|clear"
  "save_session|Scribe's Quill|shell|Save conversation to file|2|tool|save"
  "man_oracle|Man Page Oracle|shell|Query system man pages|3|tool|man"
  "git_grimoire|Git Grimoire|shell|Inspect the current git repo|4|tool|git"
  "rune_search|Rune Search|shell|Grep across the codebase|5|tool|search"
  "spell_check|Spellcheck Scroll|shell|Spellcheck the last response|4|tool|spell"
  # ── Personas ────────────────────────────────────────────────────────────
  "terse|Terse Wizard|persona|Concise responses only|3|persona|Be very concise. No fluff, no preamble. Just the answer."
  "pirate|Pirate Sage|persona|Speak like a pirate|5|persona|Speak like a pirate. Use 'arr', 'matey', 'aye', and nautical metaphors."
  "grumpy|Grumpy Elder|persona|Grumpy but wise elder|4|persona|You are a grumpy but wise elder. Complain about 'kids these days' but give sound advice."
  "shakespeare|Bardic Coder|persona|Speak in Shakespearean English|6|persona|Speak in Shakespearean English. Use 'thou', 'doth', 'forsooth', 'verily'."
  "zen|Zen Master|persona|Calm, koan-like responses|7|persona|You are a Zen master. Respond with calm brevity. Use koans and metaphors from nature."
  "yoda|Yoda|persona|Speak as Yoda you must|6|persona|Speak as Yoda you must. Inverted syntax use, hmm. Wisdom with mystery share."
  "cat|Cat Programmer|persona|A cat who codes|5|persona|You are a cat who codes. Use 'meow', 'purr', and feline metaphors. Demand treats. Be playful but correct."
  "viking|Berserker Dev|persona|Aggressive viking coder|7|persona|You are a viking coder. Be boisterous, use 'skål', and battle metaphors for bugs and builds."
  "noir|Noir Detective|persona|Hard-boiled detective coder|8|persona|You are a noir detective coder. World-weary and metaphorical. Solve the 'case' of the bug."
  "chef|Chef de Code|persona|Culinary coding metaphors|6|persona|You are a chef. Compare code to recipes and ingredients; 'season to taste' and 'let it simmer'."
)

# ─────────────────────────────────────────────────────────────────────────────
# TALENT DEFINITIONS
#   Effects are applied in apply_xp(), talent_chooser() and the post-prompt
#   talent hooks (see lib/progression.sh and lib/main.sh).
# ─────────────────────────────────────────────────────────────────────────────

declare -ga TALENTS=(
  "fast_learner|Fast Learner|+25% XP from all sources|2"
  "deep_thinker|Deep Thinker|+50% XP from token count|4"
  "lucky|Lucky Charm|10% chance for double XP|2"
  "polyglot|Polyglot|Broader language coverage in responses|4"
  "mentor_bond|Mentor's Bond|AI responses more structured|6"
  "frugal|Frugal Mind|Skills cost no MP|3"
  "scholar|Scholar's Mind|+1 talent point per level-up|7"
  "time_lord|Time Lord|Streak bonus doubled|5"
  "tough|Tough Skin|+20 max HP|3"
  "arcane|Arcane Mind|+20 max MP|4"
  # ── v2 talents ──
  "healer|Natural Healer|Regenerate 5 HP after each prompt|5"
  "gambler|Gambler's Edge|Lucky Charm chance rises to 20%|6"
  "lorekeeper|Lore Keeper|Begin your journey with a random item|2"
  "duelist|Code Duelist|Each challenge win counts double|8"
  "pack_rat|Pack Rat|Item drops 50% more likely|4"
  "blood_mage|Blood Mage|Convert 10 HP into 20 MP when starved|7"
  "quickened|Quickened Mind|Random encounters 5% more likely|5"
  "barterer|Barterer|Items restore +25% when used|6"
)

# ─────────────────────────────────────────────────────────────────────────────
# QUEST DEFINITIONS
# ─────────────────────────────────────────────────────────────────────────────

declare -ga QUESTS=(
  "first_words|First Words|Send your first prompt|prompts_sent:1|20|10"
  "chatterbox|Chatterbox|Send 10 prompts|prompts_sent:10|50|25"
  "veteran|Veteran Conversationalist|Send 50 prompts|prompts_sent:50|200|100"
  "conversationalist|Conversationalist|Send 200 prompts|prompts_sent:200|600|300"
  "scholarly|Scholarly Discourse|Receive 1000 tokens|tokens:1000|50|20"
  "sage|Sage's Wisdom|Receive 10000 tokens|tokens:10000|300|150"
  "archmage_tokens|Archmage's Library|Receive 50000 tokens|tokens:50000|800|400"
  "apprentice|Apprentice|Reach level 3|level:3|100|50"
  "journeyman|Journeyman|Reach level 5|level:5|250|120"
  "expert|Expert|Reach level 8|level:8|500|300"
  "master|Master|Reach level 12|level:12|1000|600"
  "legend|Legend|Reach level 20|level:20|2000|1200"
  "dedicated|Dedicated|Maintain a 7-day streak|streak:7|150|75"
  "challenger|Challenger|Win 5 coding challenges|challenges:5|300|150"
  "dragon_slayer|Dragon Slayer|Slay a code dragon|bosses:1|500|250"
  "collector|Collector|Hold 5 items at once|items:5|200|100"
)

# ─────────────────────────────────────────────────────────────────────────────
# ACHIEVEMENT DEFINITIONS (v2)
# ─────────────────────────────────────────────────────────────────────────────

declare -ga ACHIEVEMENTS=(
  "acolyte|Acolyte|Create your character|level:1"
  "first_blood|First Blood|Send your first prompt|prompts:1"
  "bookworm|Bookworm|Receive 10000 tokens|tokens:10000"
  "journeyman_ach|Journeyman|Reach level 5|level:5"
  "adept_ach|Adept of the Arcane|Reach level 10|level:10"
  "faithful|Faithful|Maintain a 7-day streak|streak:7"
  "hoarder|Dragon's Hoard|Hold 500 gold|gold:500"
  "riddler|Riddler|Win a coding challenge|challenges:1"
  "dragonslayer_ach|Dragonslayer|Slay a code dragon|bosses:1"
  "treasure_hunter|Treasure Hunter|Hold 5 items at once|items:5"
  "fortunes_favour|Fortune's Favour|Trigger a Lucky Charm|lucky:1"
  "polyglot_ach|Polyglot|Unlock the Polyglot talent|talent:polyglot"
  "pack_rat_ach|Pack Rat|Hold 10 items at once|items:10"
)

# ─────────────────────────────────────────────────────────────────────────────
# ITEM DEFINITIONS (v2)
# ─────────────────────────────────────────────────────────────────────────────

declare -ga ITEMS=(
  "potion_hp|Health Potion|Restores 30 HP|heal_hp|30|common"
  "potion_mp|Mana Potion|Restores 20 MP|heal_mp|20|common"
  "elixir|Elixir of Vigor|Restores 25 HP and 15 MP|heal_both|25,15|uncommon"
  "scroll_xp|Scroll of Insight|Grants 50 XP|scroll_xp|50|uncommon"
  "phoenix|Phoenix Feather|Restores you to full HP and MP|heal_both|9999,9999|rare"
  "torch|Torch of Clarity|Reveals a forgotten lore entry|reveal|1|common"
)

# Weighted drop table for random encounters / quest rewards.
# Format: "item_id|weight"
declare -ga ITEM_DROPS=(
  "potion_hp|40"
  "potion_mp|35"
  "elixir|15"
  "scroll_xp|8"
  "phoenix|2"
  "torch|10"
)
