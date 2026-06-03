# ==============================
# KXL SYSTEM - COMMANDS & ALIASES
# ==============================

# ==============================
# DETECT LS ENGINE
# ==============================
if command -v eza >/dev/null 2>&1; then
  LS="eza --icons --group-directories-first"
  LL="eza -lah --icons --group-directories-first"
  LA="eza -a --icons"
else
  LS="ls --color=auto"
  LL="ls -lah --color=auto"
  LA="ls -a --color=auto"
fi

# ==============================
# ALIASES
# ==============================
alias ls="$LS"
alias ll="$LL"
alias la="$LA"
alias l="$LS"

alias cat='batcat --paging=never --style=numbers --theme="Monokai Extended" --wrap=never --italic-text=never --color=always'
alias grep='grep --color=auto'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias dfh='df -hT'
alias ports='sudo ss -tulpn'

alias aptu='sudo apt update && apt list --upgradable'
alias aptug='sudo apt update && sudo apt full-upgrade -y'
alias aptc='sudo apt autoremove --purge -y && sudo apt autoclean -y'

alias g='git'
alias cls='clear'
alias ai-fast='OLLAMA_MODEL=qwen2.5-coder:1.5b ai'
alias ai-big='OLLAMA_MODEL=phi4-mini ai'
alias ask='ai'
alias h='history'
alias vman='/Development/scripts/version_manager.sh'
alias venccity="source /Development/projekt/cityx/venv/bin/activate && export CARGO_HOME=/Development/projekt/cityx/.cargo && export RUSTUP_HOME=/Development/projekt/cityx/.rustup"

# ==============================
# COMMAND PREVIEW + TIMING
# ==============================
EXEC_START_TIME=0

preexec() {
  EXEC_START_TIME=$(date +%s%N)
  print -P "%F{blue}➜%f %F{cyan}${1}%f"
}

precmd() {
  vcs_info
  if [[ $EXEC_START_TIME -gt 0 ]]; then
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - EXEC_START_TIME) / 1000000 ))
    if [[ $duration -gt 1000 ]]; then
      print -P "%F{dim}⌛ ${duration}ms%f"
    fi
    EXEC_START_TIME=0
  fi
}

# ==============================
# HELP FUNCTION
# ==============================
help() {
  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│              %F{yellow}SYSTEM HELP%F{cyan}                    │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────┘%f"
  print -P ""

  local zshrc_file="$HOME/.zshrc"
  local aliases=$(grep -E "^alias " "$zshrc_file" | sed -E "s/^alias //" | sort)

  print -P "%F{blue}📁 Files:%f        %F{green}$(echo "$aliases" | grep -E '^(ls|ll|la|l)=' | sed 's/=.*//' | tr '\n' ',' | sed 's/,$//')%f"
  print -P "%F{blue}📄 View:%f        %F{green}$(echo "$aliases" | grep -E '^cat=' | sed 's/=.*//' | tr '\n' ',' | sed 's/,$//')%f"
  print -P "%F{blue}📜 History:%f     %F{green}$(echo "$aliases" | grep -E '^h=' | sed 's/=.*//' | tr '\n' ',' | sed 's/,$//')%f"
  print -P "%F{blue}🌐 Network:%f     %F{green}$(echo "$aliases" | grep -E '^ports=' | sed 's/=.*//' | tr '\n' ',' | sed 's/,$//')%f"
  print -P "%F{blue}💻 System:%f      %F{green}$(echo "$aliases" | grep -E '^(aptu|aptug|aptc|dfh)=' | sed 's/=.*//' | tr '\n' ',' | sed 's/,$//')%f"
  print -P "%F{blue}🔧 Tools:%f       %F{green}$(echo "$aliases" | grep -E '^(g|cls)=' | sed 's/=.*//' | tr '\n' ',' | sed 's/,$//')%f"
  print -P "%F{blue}🧭 Navigation:%f  %F{green}$(echo "$aliases" | grep -E '^(\.\.|\.\.\.|\.\.\.\.)=' | sed 's/=.*//' | tr '\n' ',' | sed 's/,$//')%f"
  print -P "%F{blue}🤖 AI:%f          %F{green}$(echo "$aliases" | grep -E '^(ai|ask)=' | sed 's/=.*//' | tr '\n' ',' | sed 's/,$//')%f"

  print -P ""
  print -P "%F{magenta}💡 TIP:%f  %F{yellow}man <polecenie>%f - szczegółowa dokumentacja poleceń (np. %F{green}man ls%f, %F{green}man grep%f)"
  print -P ""
  print -P "%F{cyan}📋 Wszystkie aliasy:%f"
  echo "$aliases" | while read -r line; do
    local name=$(echo "$line" | sed 's/=.*//')
    local cmd=$(echo "$line" | sed "s/^[^=]*=//" | sed "s/'//g")
    print -P "   %F{green}$name%f → %F{blue}$cmd%f"
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  print -P ""
  print -P "%F{yellow}Type 'welcome' for system info%f"
  print -P ""
}

# ==============================
# COMMAND NOT FOUND HANDLER
# ==============================

suggest_local() {
  local cmd="$1"
  local search_term="${cmd:0:2}"
  local found=0

  print -P ""
  print -P "%F{blue}🔍 Szukam podobnych poleceń dla:%f %F{yellow}$cmd%f"
  print -P "%F{blue}────────────────────────────────────────────────%f"

  local aliases=$(alias 2>/dev/null | grep -i "^alias.*${cmd}" | head -5)
  if [[ -n "$aliases" ]]; then
    print -P ""
    print -P "%F{green}📋 Aliasy:%f"
    echo "$aliases" | while read line; do
      local alias_name=$(echo "$line" | sed "s/alias //" | cut -d= -f1)
      print -P "   %F{cyan}$alias_name%f"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    found=1
  fi

  local found_cmds=()
  for dir in ${=PATH}; do
    if [[ -d "$dir" ]]; then
      local matches=$(ls "$dir" 2>/dev/null | grep -i "^${cmd}" | head -10)
      if [[ -n "$matches" ]]; then
        for m in ${=matches}; do
          found_cmds+=("$m")
        done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
      fi
    fi
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  if [[ ${#found_cmds[@]} -gt 0 ]]; then
    print -P ""
    print -P "%F{green}🔧 Polecenia w PATH:%f"
    local unique_cmds=($(echo "${found_cmds[@]}" | tr ' ' '\n' | sort -u))
    for c in "${unique_cmds[@]}"; do
      print -P "   %F{cyan}$c%f"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    found=1
  fi

  local funcs=$(functions 2>/dev/null | grep -i "^${cmd}" | head -5)
  if [[ -n "$funcs" ]]; then
    print -P ""
    print -P "%F{green}⚡ Funkcje:%f"
    echo "$funcs" | while read line; do
      print -P "   %F{cyan}$(echo "$line" | cut -d' ' -f1)%f"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    found=1
  fi

  if [[ $found -eq 0 ]]; then
    print -P ""
    print -P "%F{yellow}⚠️  Nie znaleziono podobnych poleceń%f"
  fi

  print -P ""
}

command_not_found_handler() {
  local cmd="$1"
  print -P ""
  print -P "%F{red}┌──────────────────────────────────────────────┐%f"
  print -P "%F{red}│%F{yellow} ✖ COMMAND NOT FOUND%F{red}                      │%f"
  print -P "%F{red}└──────────────────────────────────────────────┘%f"
  print -P ""
  print -P "%F{red}  Command:%f %F{yellow}$cmd%f"
  print -P "%F{red}  Exit code:%f %F{yellow}127%f"
  print -P "%F{red}  Working dir:%f %F{yellow}$PWD%f"
  print -P "%F{red}  Time:%f %F{yellow}$(date +%H:%M:%S)%f"
  print -P ""
  print -P "%F{blue}  Wybierz opcję:%f"
  print -P "   %F{green}[L]okalne%f  - szukaj podobnych poleceń"
  print -P "   %F{yellow}[N]ie%f     - ignoruj"
  print -P ""

  local choice
  read -q "choice? > "
  print -P ""

  if [[ "$choice" == "l" || "$choice" == "L" ]]; then
    suggest_local "$cmd"
  fi

  return 127
}



who() {
  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│%F{yellow} 👤 INFORMACJE O UŻYTKOWNIKACH%F{cyan}                      │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
  print -P ""

  local show_all=false
  local show_short=false

  if [[ "$1" == "-a" || "$1" == "--all" ]]; then
    show_all=true
  elif [[ "$1" == "-s" || "$1" == "--short" ]]; then
    show_short=true
  fi

  if [[ "$show_short" == "true" ]]; then
    print -P "%F{magenta}UŻYTKOWNIK       TTY        DATASLOGOWANIA    DZIEŃ%f"
    command who | while read -r line; do
      local user=$(echo "$line" | awk '{print $1}')
      local tty=$(echo "$line" | awk '{print $2}' | cut -d: -f1)
      local date=$(echo "$line" | awk '{print $3, $4}')
      local day=$(echo "$line" | awk '{print $5}')
      echo -E " $user $tty $date $day"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  else
    print -P "%F{magenta}UŻYTKOWNIK       TTY        LOGIN TIME                  OPCJONALNIE%f"
    command who | while read -r line; do
      local user=$(echo "$line" | awk '{print $1}')
      local tty=$(echo "$line" | awk '{print $2}' | cut -d: -f1)
      local rest=$(echo "$line" | sed "s/^[^ ]* *[^ ]* *//")
      echo -E " $user $tty $rest"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  fi

  print -P ""
  local count=$(command who -q | tail -n 1 | awk '{print $3}' | tr -d '#=')
  [[ -z "$count" ]] && count=0
  print -P "%F{green}✓%f Łącznie: %F{yellow}$count%f użytkownik(ów)"
  print -P ""
}

# ==============================
# WHO/W ENHANCED
# ==============================

w() {
  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│%F{yellow} 👥 AKTYWNI UŻYTKOWNIICY%F{cyan}                              │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
  print -P ""
  command w
  print -P ""
}

# ==============================
# AI - OLLAMA ASSISTANT
# ==============================

ai() {
  local prompt="$*"

  if [ -z "$prompt" ]; then
    print -P ""
    print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
    print -P "%F{cyan}│%F{yellow} 🤖 OLLAMA AI ASSISTANT%F{cyan}                            │%f"
    print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
    print -P ""
    print -P "%F{yellow}Użycie:%f ai \"twoje pytanie\""
    print -P "%F{green}Przykłady:%f"
    print -P "   ai \"Co to jest Linux?\""
    print -P "   ai \"Jak wyświetlić pliki w terminalu?\""
    print -P "   ai \"Napisz skrypt bash do backupu\""
    print -P ""
    print -P "%F{blue}Model:%f %F{white}$OLLAMA_MODEL%f"
    print -P "%F{blue}Host:%f %F{white}$OLLAMA_HOST%f"
    print -P ""
    print -P "%F{magenta}Tip:%f Użyj %F{green}aimsg%f dla trybu konwersacyjnego z historią"
    print -P ""
    return 0
  fi

  print -P ""
  print -P "%F{cyan}🤖%f %F{yellow}Pytanie:%f $prompt"
  print -P "%F{dim}─────────────────────────────────────────────────────%f"

  local response=$(curl -s "$OLLAMA_HOST/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"$prompt\",\"stream\":true}" \
    2>/dev/null | jq -r '.response // empty')

  if [[ -n "$response" ]]; then
    print -P "%F{green}Odpowiedź:%f"
    print -P ""
    echo "$response" | fold -w 80 -s | while read -r line; do
      print -P "  %F{white}$line%f"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  else
    print -P "%F{red}✗ Błąd:%f Nie można połączyć z Ollama"
    print -P "%F{yellow}Sprawdź czy serwis działa:%f curl $OLLAMA_HOST"
  fi
  print -P ""
}

aimsg() {
  local messages=()

  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│%F{yellow} 💬 TRYB KONWERSACYJNY AI%F{cyan}                            │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
  print -P ""
  print -P "%F{green}Wpisz pytanie lub %F{red}quit%F{green} aby wyjść%f"
  print -P ""

  while true; do
    print -P "%F{blue}❯%f \c"
    local input
    read input
    [[ "$input" == "quit" || "$input" == "q" || "$input" == "exit" ]] && break
    [[ -z "$input" ]] && continue

    print -P "%F{yellow}→%f $input"
    print -P "%F{dim}─────────────────────────────────────────────────────%f"

    local response=$(curl -s "$OLLAMA_HOST/api/generate" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"$input\",\"stream\":false}" \
      2>/dev/null | sed -n 's/.*"response":"\([^"]*\)".*/\1/p')

    if [[ -n "$response" ]]; then
      echo "$response" | fold -w 70 -s | while read -r line; do
        print -P "  %F{white}$line%f"
      done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    else
      print -P "%F{red}✗ Błąd połączenia%f"
    fi
    print -P ""
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  print -P "%F{cyan}Do zobaczenia! 👋%f"
  print -P ""
}

ai-tokens() {
  local prompt="${*:-Tell me a joke}"

  local response=$(curl -s "$OLLAMA_HOST/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"$prompt\",\"stream\":false}" \
    2>/dev/null)

  if [[ -n "$response" ]]; then
    local prompt_eval=$(echo "$response" | jq -r '.prompt_eval_count // empty' 2>/dev/null)
    local eval_count=$(echo "$response" | jq -r '.eval_count // empty' 2>/dev/null)
    local duration=$(echo "$response" | jq -r '.eval_duration // empty' 2>/dev/null)

    print -P ""
    print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
    print -P "%F{cyan}│%F{yellow} 📊 OLLAMA TOKEN USAGE%F{cyan}                              │%f"
    print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
    print -P ""
    print -P "%F{green}Model:%f        %F{white}$OLLAMA_MODEL%f"
    print -P "%F{green}Prompt tokens:%f %F{yellow}$prompt_eval%f"
    print -P "%F{green}Eval tokens:%f   %F{yellow}$eval_count%f"

    if [[ -n "$duration" && "$duration" != "null" ]]; then
      local duration_sec=$(echo "$duration / 1000000000" | bc -l 2>/dev/null || echo "$duration")
      print -P "%F{green}Duration:%f     %F{yellow}${duration_sec}s%f"
      if [[ -n "$eval_count" && "$eval_count" != "0" ]]; then
        local tokens_per_sec=$(echo "scale=2; $eval_count / ($duration / 1000000000)" | bc -l 2>/dev/null || echo "N/A")
        print -P "%F{green}Tokens/sec:%f   %F{yellow}$tokens_per_sec%f"
      fi
    fi

    print -P ""
    local total_tokens=$((prompt_eval + eval_count))
    print -P "%F{magenta}Total tokens:%f %F{white}$total_tokens%f"
    print -P ""
  else
    print -P "%F{red}✗ Błąd:%f Nie można połączyć z Ollama"
  fi
}

ai-models() {
  local ollama_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags 2>/dev/null)

  if [[ "$ollama_status" != "200" ]]; then
    print -P "%F{red}✗ Ollama not running%f"
    return 1
  fi

  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│%F{yellow} 📦 OLLAMA MODELS%F{cyan}                                    │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
  print -P ""
  print -P "%F{magenta}%-30s %15s %15s%f" "MODEL" "SIZE" "LAST ACCESSED"
  print -P "%F{dim}$(printf '%.0s─' {1..60})%f"

  curl -s http://localhost:11434/api/tags | jq -r '.models[] | "\(.name)|\(.size)|\(.modified_at)"' 2>/dev/null | while IFS='|' read -r name size modified; do
    local size_gb=$(echo "scale=2; $size / 1024 / 1024 / 1024" | bc -l 2>/dev/null || echo "$size")
    print -P "%F{green}%-30s%f %F{yellow}%12s GB%f %F{blue}%s%f" "$name" "$size_gb" "$modified"
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  print -P ""
  print -P "%F{blue}Current model:%f %F{white}$OLLAMA_MODEL%f"
  print -P "%F{blue}Context window:%f %F{white}$OLLAMA_NUM_CTX%f"
  print -P ""
}

ai-bench() {
  local test_prompt="Explain what artificial intelligence is in one sentence."

  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│%F{yellow} ⚡ OLLAMA MODEL BENCHMARK%F{cyan}                             │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
  print -P ""
  print -P "%F{blue}Test prompt:%f %F{white}$test_prompt%f"
  print -P ""

  local models_json=$(curl -s http://localhost:11434/api/tags 2>/dev/null)
  local model_count=$(echo "$models_json" | jq '.models | length')

  if [[ "$model_count" -eq 0 ]]; then
    print -P "%F{red}✗ No models found%f"
    return 1
  fi

  print -P "%F{magenta}%-25s %10s %10s %10s %10s%f" "MODEL" "PROMPT" "EVAL" "TOTAL" "TOK/S"
  print -P "%F{dim}$(printf '%.0s─' {1..70})%f"

  local i=0
  while [[ $i -lt $model_count ]]; do
    local model=$(echo "$models_json" | jq -r ".models[$i].name")

    local response=$(curl -s "$OLLAMA_HOST/api/generate" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$model\",\"prompt\":\"$test_prompt\",\"stream\":false}" \
      2>/dev/null)

    if [[ -n "$response" ]]; then
      local prompt_eval=$(echo "$response" | jq -r '.prompt_eval_count' 2>/dev/null)
      local eval_count=$(echo "$response" | jq -r '.eval_count' 2>/dev/null)
      local duration=$(echo "$response" | jq -r '.eval_duration // .total_duration' 2>/dev/null)

      local total=0
      local tokens_per_sec="N/A"

      if [[ -n "$prompt_eval" && "$prompt_eval" != "null" && -n "$eval_count" && "$eval_count" != "null" ]]; then
        total=$((prompt_eval + eval_count))

        if [[ -n "$duration" && "$duration" != "null" && "$duration" != "0" ]]; then
          tokens_per_sec=$(echo "scale=2; $eval_count / ($duration / 1000000000)" | bc -l 2>/dev/null)
        fi
      fi

      prompt_eval=${prompt_eval:-0}
      eval_count=${eval_count:-0}
      [[ "$prompt_eval" == "null" ]] && prompt_eval=0
      [[ "$eval_count" == "null" ]] && eval_count=0

      print -P "%F{green}%-25s%f %F{yellow}%10s%f %F{yellow}%10s%f %F{magenta}%10s%f %F{cyan}%10s%f" \
        "$model" "$prompt_eval" "$eval_count" "$total" "$tokens_per_sec"
    else
      print -P "%F{red}%-25s%f %F{red}FAILED%f" "$model"
    fi

    ((i++))
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  print -P ""
}

ai-test() {
  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│%F{yellow} 🧪 OLLAMA TEST%F{cyan}                                     │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
  print -P ""

  local start_time=$(date +%s%N)

  local response=$(curl -s "$OLLAMA_HOST/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"Hello\",\"stream\":false}" \
    2>/dev/null)

  local end_time=$(date +%s%N)
  local duration=$(( (end_time - start_time) / 1000000 ))

  if [[ -n "$response" ]]; then
    local status="OK"
    print -P "%F{green}✓%f Status:    %F{white}$status%f"
    print -P "%F{green}✓%f Model:     %F{white}$OLLAMA_MODEL%f"
    print -P "%F{green}✓%f Latency:   %F{white}${duration}ms%f"
    print -P "%F{green}✓%f Host:      %F{white}$OLLAMA_HOST%f"
    print -P ""
    print -P "%F{blue}Response preview:%f"
    local preview=$(echo "$response" | jq -r '.response' | cut -c1-100)
    print -P "%F{white}$preview...%f"
    print -P ""
  else
    print -P "%F{red}✗ Status:%f    %F{white}FAILED%f"
    print -P "%F{red}✗ Message:%f  %F{white}Cannot connect to Ollama%f"
    print -P ""
  fi
}

# ==============================
# HISTORY
# ==============================

history() {
  local search_term=""
  local show_stats=false
  local limit=50

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--search)
        search_term="$2"
        shift 2
        ;;
      -n|--number)
        limit="$2"
        shift 2
        ;;
      --stats)
        show_stats=true
        shift
        ;;
      *)
        search_term="$1"
        shift
        ;;
    esac
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  if [[ "$show_stats" == "true" ]]; then
    print -P ""
    print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
    print -P "%F{cyan}│%F{yellow} 📊 STATYSTYKI HISTORII%F{cyan}                                │%f"
    print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
    print -P ""
    print -P "%F{green}Całkowita liczba poleceń:%f %F{yellow}$HISTFILE (ostatnie $(fc -l -t | tail -n 1))%f"
    print -P "%F{green}Rozmiar historii:%f %F{yellow}$HISTSIZE poleceń%f"
    print -P "%F{green}Zapisana historia:%f %F{yellow}$SAVEHIST poleceń%f"
    print -P ""

    local top_cmds=$(history | awk '{print $2}' | sort | uniq -c | sort -rn | head -10)
    print -P "%F{magenta}Top 10 używanych poleceń:%f"
    echo "$top_cmds" | while read -r count cmd; do
      [[ -n "$cmd" ]] && print -P "   %F{yellow}$count%f × %F{cyan}$cmd%f"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    print -P ""
    return 0
  fi

  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│%F{yellow} 📜 HISTORIA POLECEŃ%F{cyan}                                   │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
  print -P ""

  if [[ -n "$search_term" ]]; then
    print -P "%F{blue}🔍 Szukam:%f %F{yellow}$search_term%f"
    print -P "%F{dim}$(printf '%.0s─' {1..60})%f"
    fc -l -t -${limit} 2>/dev/null | grep -i "$search_term" | while read -r line; do
      local num=$(echo "$line" | awk '{print $1}')
      local cmd=$(echo "$line" | sed 's/^[0-9]*[ *]*//')
      local time=$(echo "$line" | awk '{print $2, $3}')
      print -P " %F{green}$num%f  %F{dim}$time%f  %F{white}$cmd%f"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  else
    print -P "%F{magenta}%-6s %-8s %s%f" "NR" "CZAS" "POLECENIE"
    print -P "%F{dim}$(printf '%.0s─' {1..70})%f"
    fc -l -t -${limit} 2>/dev/null | while read -r line; do
      local num=$(echo "$line" | awk '{print $1}')
      local cmd=$(echo "$line" | sed 's/^[0-9]*[ *]*//')
      local time=$(echo "$line" | awk '{print $2, $3}')
      print -P " %F{green}$num%f  %F{yellow}$time%f  %F{white}$cmd%f"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  fi

  print -P ""
  print -P "%F{blue}💡 Użyj:%f %F{green}h -s <słowo>%f - szukaj w historii"
  print -P "         %F{green}h --stats%f - pokaż statystyki"
  print -P ""
}

# ==============================
# UTILITY FUNCTIONS
# ==============================

mkcd() { mkdir -p "$1" && cd "$1"; }
cdp() { cd "$1" && ls; }

extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz) tar xzf "$1" ;;
      *.bz2) bunzip2 "$1" ;;
      *.rar) unrar x "$1" ;;
      *.gz) gunzip "$1" ;;
      *.tar) tar xf "$1" ;;
      *.tbz2) tar xjf "$1" ;;
      *.tgz) tar xzf "$1" ;;
      *.zip) unzip "$1" ;;
      *.Z) uncompress "$1" ;;
      *.7z) 7z x "$1" ;;
      *) echo "'$1' cannot be extracted" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

backup() { cp "$1" "${1}.bak.$(date +%Y%m%d_%H%M%S)"; }

server() {
  echo "=== Server Status ==="
  echo "Load: $(uptime | awk '{print $NF}')"
  echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
  echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
  echo "Uptime: $(uptime -p)"
}

weather() { curl -s "wttr.in/${1:-Warsaw}?format=3" || echo "Weather unavailable"; }

unalias myip 2>/dev/null
myip() {
  echo "External: $(curl -s ifconfig.me)"
  echo "Local: $(hostname -I | awk '{print $1}')"
}

docker-ps() { docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; }

# ==============================
# GITHUB SHORTCUTS
# ==============================

gh-show() { /Development/scripts/version_manager.sh show; }
gh-update() { /Development/scripts/version_manager.sh update "$1" "$2"; }
gh-push() { /Development/scripts/version_manager.sh push "$1" "$2"; }
gh-log() { /Development/scripts/version_manager.sh log "$1"; }
gh-status() { /Development/scripts/version_manager.sh status "$1"; }
gh-help() { /Development/scripts/version_manager.sh help; }

# ==============================
# UNIFIED CONFIG SYNC
# ==============================

ya-sync() {
  local msg="${1:-Update configuration and projects}"
  local about_root="/root/About"
  local whitekali_root="/root/whitekali_repo"
  
  # Helper to print if zsh, else echo
  _ya_log() {
    if [[ -n "$ZSH_VERSION" ]]; then print -P "$1"; else echo "$1" | sed 's/%F{[^}]*}//g;s/%f//g'; fi
  }

  _ya_log "%F{cyan}🔄 Starting Unified Configuration Sync...%f"
  
  # 1. Ensure About is updated with system config
  if [[ -d "$about_root" ]]; then
    _ya_log "%F{blue}📁 Syncing System -> About...%f"
    local conf_dir="$about_root/linux/own"
    mkdir -p "$conf_dir/.zsh"
    cp /root/.zshrc "$conf_dir/"
    cp /root/.zshenv "$conf_dir/"
    cp /root/.bashrc "$conf_dir/"
    cp /root/.profile "$conf_dir/"
    cp /root/.zsh/commands.sh "$conf_dir/.zsh/"
    cp /root/.zsh/welcome.sh "$conf_dir/.zsh/"
    cp /root/.zsh/welcome_engine.sh "$conf_dir/.zsh/"
    sed -i 's/export GITHUB_TOKEN=.*/export GITHUB_TOKEN="YOUR_GITHUB_TOKEN_HERE"/' "$conf_dir/.zshrc"
  fi

  # 2. Sync About -> Ya-Whitekali
  if [[ -d "$about_root" && -d "$whitekali_root" ]]; then
    _ya_log "%F{blue}🔗 Bridging About -> Ya-Whitekali...%f"
    mkdir -p "$whitekali_root/about" "$whitekali_root/linux-config/.zsh"
    
    # Sync Analysis
    [[ -f "$about_root/CONFIGURATION.md" ]] && cp "$about_root/CONFIGURATION.md" "$whitekali_root/about/"
    
    # Sync Config Files from About (already masked)
    cp -r "$about_root/linux/own/." "$whitekali_root/linux-config/"
    
    # Update sync status for the website
    local sync_time=$(date +"%Y-%m-%d %H:%M:%S")
    mkdir -p "$whitekali_root/assets/data"
    echo "{\"last_sync\": \"$sync_time\", \"status\": \"Success\", \"message\": \"$msg\"}" > "$whitekali_root/assets/data/sync_status.json"
  fi

  # 3. Git Push both
  for repo in "$about_root" "$whitekali_root"; do
    if [[ -d "$repo" ]]; then
      (
        cd "$repo"
        local branch=$(git branch --show-current)
        git add .
        if [[ -n $(git status --short) ]]; then
          git commit -m "$msg"
          git push origin "$branch"
          _ya_log "%F{green}✓ $(basename "$repo") updated and pushed to $branch%f"
        else
          _ya_log "%F{yellow}ℹ No changes in $(basename "$repo")%f"
        fi
      )
    fi
  done
  
  _ya_log "%F{green}✨ Unified Sync complete!%f"
}

help-gh() {
    cat << 'HELP'
========================================
📖 GITHUB - POMOC DLA DAWJU9
========================================

Skróty dostępne w terminalu:

🚀 KONFIGURACJA:
  ya-sync "msg"           - Synchronizuj system z repozytoriami About i Ya-Whitekali

📦 WERSJE:
  vman                    - Pokaz wersje wszystkich projektów
  gh-show                 - To samo co vman show

📈 AKTUALIZACJE:
  gh-update framework     - Zwiększ wersję framework (patch)
  gh-update game minor  - Zwiększ wersję game (minor)
  gh-update web major  - Zwiększ wersję web (major)

📤 PUSH:
  gh-push framework    - Push framework do GitHub
  gh-push game "msg"   - Push game z wiadomością

📜 HISTORIA:
  gh-log framework     - Pokaż historię commitów
  gh-log game

🔍 STATUS:
  gh-status framework  - Sprawdź status git
  gh-status game

❓ POMOC:
  gh-help               - Ta pomoc

Przykłady użycia:
  ya-sync "Dodano nowe aliasy"
  vman
  gh-update game patch
  gh-push framework "Poprawki bugów"
HELP
}

# ==============================
# SCHEMAT VISUALIZER
# ==============================

schemat() {
  local file="$1"

  if [[ -z "$file" ]]; then
    print -P ""
    print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
    print -P "%F{cyan}│%F{yellow} 🏙️ SCHEMAT VISUALIZER%F{cyan}                                │%f"
    print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
    print -P ""
    print -P "%F{green}Usage:%f schemat <plik.xml>"
    print -P ""
    print -P "%F{blue}Examples:%f"
    print -P "   schemat miasto1schemat.xml"
    print -P "   schemat miasto2schemat.xml"
    print -P ""
    return 0
  fi

  local schemat_dir="/Development/repos/SchematicsAgent"
  local full_path="$schemat_dir/$file"

  if [[ ! -f "$full_path" ]]; then
    print -P "%F{red}✗ File not found:%f $file"
    return 1
  fi

  print -P ""
  print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
  print -P "%F{cyan}│%F{yellow} 🏙️ WIZUALIZACJA SCHEMATU%F{cyan}                              │%f"
  print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
  print -P ""
  print -P "%F{green}File:%f %F{white}$file%f"
  print -P ""

  python3 "$schemat_dir/viz_city.py" "$full_path"

  print -P ""
  print -P "%F{blue}Legenda:%f"
  print -P " %F{green}B%f - Budynek  %F{yellow}L%f - Lampa  %F{white}═%f - Zebra  %F{red}#%f - Brama"
  print -P ""
}

# ==============================
# SCREEN MANAGER
# ==============================

function lscreen {
  local sessions
  sessions=$(screen -ls 2>/dev/null | grep -E "[0-9]+\." | awk '{print $1, $2, $3" "$4" "$5" "$6" "$7" "$8" "$9" "$10}')

  if [[ -z "$sessions" ]]; then
    echo "No active screen sessions"
    return 0
  fi

  echo "Current screen sessions:"
  echo "$sessions" | nl -w2 -s ". "
  echo ""
  echo "Options:"
  echo "  [k] Kill session"
  echo "  [d] Detach session"
  echo "  [q] Quit"
  echo ""
  echo -n "Select session number: "; read num
  echo -n "Select action [k/d/q]: "; read action

  case "$action" in
    k|K)
      local sess
      sess=$(echo "$sessions" | sed -n "${num}p" | awk '{print $1}')
      if [[ -n "$sess" ]]; then
        screen -S "$sess" -X quit
        echo "Session $sess killed"
      fi
      ;;
    d|D)
      sess=$(echo "$sessions" | sed -n "${num}p" | awk '{print $1}')
      if [[ -n "$sess" ]]; then
        screen -d "$sess"
        echo "Session $sess detached"
      fi
      ;;
    *)
      return 0
      ;;
  esac
}

# ==============================
# FOG - SMART DIRECTORY JUMP
# ==============================

fog() {
  local target="$1"

  if [[ -z "$target" ]]; then
    print -P ""
    print -P "%F{cyan}┌─────────────────────────────────────────────────────┐%f"
    print -P "%F{cyan}│%F{yellow}  FOG - szybkie skakanie do katalogów%F{cyan}                  │%f"
    print -P "%F{cyan}└─────────────────────────────────────────────────────┘%f"
    print -P ""
    print -P "%F{green}Użycie:%f fog <nazwa_katalogu>"
    print -P "%F{blue}Przykład:%f fog Development   # → /Development"
    print -P "%F{blue}         %f fog cityx          # → /Development/projekt/cityx"
    print -P ""
    return 1
  fi

  local dirs=()

  for base in /Development /home ~; do
    [[ -d "$base/$target" ]] && dirs+=("$base/$target")
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  if [[ ${#dirs} -eq 0 ]]; then
    if command -v locate &>/dev/null; then
      dirs=($(locate -b "/$target" 2>/dev/null | head -20))
    fi
  fi

  if [[ ${#dirs} -eq 0 ]]; then
    dirs=($(find / -type d -name "$target" 2>/dev/null | head -20))
  fi

  case ${#dirs} in
    0)
      print -P "%F{red}✗ Nie znaleziono katalogu: %F{yellow}$target%f"
      return 1
      ;;
    1)
      builtin cd "${dirs[1]}" && ls
      ;;
    *)
      print -P "%F{yellow}Znaleziono %F{green}${#dirs[@]}%F{yellow} katalogów:%f"
      print -P ""
      local i=1
      for d in "${dirs[@]}"; do
        print -P "  %F{green}$i%f) %F{white}$d%f"
        ((i++))
      done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
      print -P ""
      local choice
      read "choice?%F{blue}Wybierz numer (lub Enter = anuluj):%f "
      if [[ -n "$choice" && "$choice" =~ ^[0-9]+$ && $choice -ge 1 && $choice -le ${#dirs[@]} ]]; then
        builtin cd "${dirs[$choice]}" && ls
      fi
      ;;
  esac
}

# ==============================
# WELCOME / REPO COMMANDS
# ==============================

# welcome-engine - wyświetl info o bieżącym katalogu (lub podanym)
we() {
  local target="${1:-.}"
  bash /root/.zsh/welcome_engine.sh "$target"
}

# we-init - wygeneruj .welcome.conf w bieżącym katalogu
we-init() {
  local target="${1:-.}"
  if [[ -f "$target/.welcome.conf" ]]; then
    echo "❌ .welcome.conf już istnieje w $target"
    return 1
  fi
  if [[ -f /root/.zsh/welcome.conf.template ]]; then
    cp /root/.zsh/welcome.conf.template "$target/.welcome.conf"
    echo "✓ Skopiowano template do $target/.welcome.conf"
    echo "💡 Edytuj PROJECT_NAME, PROJECT_DESC, TECH_STACK"
  else
    bash /root/.zsh/welcome_engine.sh --generate "$target"
  fi
}

# we-md - parsuj i pokaż strukturę markdown file
we-md() {
  local file="${1:-README.md}"
  if [[ ! -f "$file" ]]; then
    echo "❌ Plik nie istnieje: $file"
    return 1
  fi
  echo "📖 Markdown: $file"
  echo "────────────────────────────────────────"
  echo "Tytuł:"
  bash /root/.zsh/welcome_engine.sh --help >/dev/null 2>&1
  source /root/.zsh/welcome_engine.sh 2>/dev/null
  md_get_title "$file"
  echo ""
  echo ""
  echo "Opis:"
  md_get_description "$file"
  echo ""
  echo ""
  echo "Tech Stack (z sekcji Technologie/Tech):"
  md_get_tech_stack "$file" | head -8
  echo ""
  echo "Features:"
  md_get_items "## Features" "$file" 2>/dev/null | head -5
  [[ $(md_get_items "## Features" "$file" 2>/dev/null | wc -l) -eq 0 ]] && md_get_items "## 🎮 Funkcje" "$file" 2>/dev/null | head -5
  echo ""
  echo "Capabilities:"
  md_get_items "## Capabilities" "$file" 2>/dev/null | head -5
}

# we-repos - wyświetl welcome dla wszystkich repo w /Development
we-repos() {
  local found=0
  for base in /Development/projekt /Development/repos /Development/Rest; do
    [[ -d "$base" ]] || continue
    for dir in "$base"/*; do
      [[ -d "$dir" ]] || continue
      if [[ -f "$dir/.welcome.conf" ]]; then
        found=$((found + 1))
        local name=$(basename "$dir")
        local version=$(grep -E '^VERSION=' "$dir/.welcome.conf" 2>/dev/null | head -1 | sed 's/VERSION=//;s/"//g')
        local type=$(grep -E '^PROJECT_TYPE=' "$dir/.welcome.conf" 2>/dev/null | head -1 | sed 's/PROJECT_TYPE=//;s/"//g')
        printf "  %-25s v%-10s  %s\n" "$name" "${version:-?}" "${type:-?}"
      fi
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  echo ""
  echo "Znaleziono: $found repozytoriów z .welcome.conf"
  echo "Użyj: cd <repo> && welcome  lub  we /path/to/repo"
}

# we-health - sprawdź health check dla bieżącego projektu
we-health() {
  local dir="${1:-.}"
  if [[ ! -f "$dir/.welcome.conf" ]]; then
    echo "❌ Brak .welcome.conf w $dir"
    return 1
  fi
  source "$dir/.welcome.conf" 2>/dev/null
  if [[ -z "${HEALTH_CHECK_FILES[*]:-}" ]]; then
    echo "⚠️  Brak HEALTH_CHECK_FILES w .welcome.conf"
    return 1
  fi
  echo "🏥 Health Check: $dir"
  echo "────────────────────────────────────────"
  local f
  local ok=0
  local fail=0
  for f in "${HEALTH_CHECK_FILES[@]}"; do
    if [[ -e "$dir/$f" ]]; then
      printf "  ✓ %s\n" "$f"
      ok=$((ok + 1))
    else
      printf "  ✗ %s (brak)\n" "$f"
      fail=$((fail + 1))
    fi
  done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  echo "────────────────────────────────────────"
  echo "OK: $ok | FAIL: $fail"
  [[ $fail -gt 0 ]] && return 1
  return 0
}

# Aliasy dla wygody
alias welcome-engine='we'
alias we-show='we'
alias we-repos-list='we-repos'



# ========================================================================


# ========================================================================
# LOGBOOK CLI v2
# ========================================================================
lb(){
  local c=${1:-help} a=$2 a2=$3
  local D=/var/log/kxl/users
  local C1='\033[0m' C2='\033[2m' CG='\033[1;32m' CY='\033[1;33m' CR='\033[1;31m' CC='\033[1;36m'

  # nullglob: zsh nie bladuje na pustych globach
  [[ -n "${ZSH_VERSION:-}" ]] && setopt nullglob 2>/dev/null; [[ -n "${BASH_VERSION:-}" ]] && shopt -s nullglob 2>/dev/null
  case $c in
  users)
    printf "\n${CC}  %-18s %6s %8s  %s${C1}\n" USER DAYS CMDS LAST_CMD
    printf "${CC}  %-18s %6s %8s  %s${C1}\n" "──────────────────" "────" "────────" "──────────────────────────"
    local udir
    while IFS= read -r -d "" udir; do
      [[ -d $udir ]] || continue
      local u=$(basename $udir)
      local f="$(ls -t $udir/*.log 2>/dev/null | head -1)"
      [[ -z $f ]] && continue
      local days=$(ls -1t $udir/*.log* 2>/dev/null | wc -l)
      local cmds=$(cat $udir/*.log 2>/dev/null | grep -c '|CMD|' || echo 0)
      local last=$(grep '|CMD|' $f 2>/dev/null | tail -1 | cut -d'|' -f1,5 | tr '|' ' ')
      printf "  ${CG}%-18s${C1} ${CY}%6d${C1} ${CY}%8d${C1}  ${C2}%s${C1}\n" "$u" "$days" "$cmds" "${last:0:40}"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    echo
    ;;

  tail|t)
    local n=${a:-20}
    local u=${a:-root}
    [[ $a =~ ^[0-9]+$ ]] && u=${a2:-root} || n=20
    local lf=$(ls -t $D/$u/*.log 2>/dev/null | head -1)
    [[ -z $lf ]] && { printf "  ${CR}Brak logow: %s${C1}\n" "$u"; return 1; }
    printf "\n${CC}  ┌─ OSTATNIE %d KOMEND ── %s ────${C1}\n" "$n" "$u"
    grep '|CMD|' $lf 2>/dev/null | tail -$n | \
      awk -F'|' '{t=substr($1,12,8); d=$5; if(length(d)>50) d=substr(d,1,47)"..."; printf "  %-9s  %s\n", t, d}'
    printf "${CC}  └───────────────────────────────────────────────────${C1}\n\n"
    ;;

  search|s)
    [[ -z $a ]] && { printf "  ${CR}lb search <wzorzec> [uzytkownik]${C1}\n"; return 1; }
    local u=${a2:-}; local target=$D
    [[ -n $u ]] && target=$D/$u
    printf "\n${CC}  Szukam: ${CY}%s${C1} w ${C2}%s${C1}\n" "$a" "$target"
    find $target -name '*.log' -exec grep -il "$a" {} + 2>/dev/null | while read f; do
      local u2=$(echo $f | awk -F/ '{print $5}')
      grep -i "$a" "$f" 2>/dev/null | grep '|CMD|' | tail -15 | \
        awk -v u="$u2" -F'|' '{printf "  %-10s %-9s %s\n", u, substr($1,12,8), $5}'
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    echo
    ;;

  stats)
    local u=${a:-root}; local d=$D/$u
    [[ ! -d $d ]] && { printf "  ${CR}Brak danych: %s${C1}\n" "$u"; return 1; }
    local total=$(cat $d/*.log 2>/dev/null | grep -c '|CMD|' || echo 0)
    local fails=$(cat $d/*.log 2>/dev/null | grep -c '|CMD_FAIL|' || echo 0)
    local sess=$(cat $d/*.log 2>/dev/null | grep -c '|SESSION_INIT|' || echo 0)
    local secs=$(cat $d/*.log 2>/dev/null | grep '|SESSION_END|' | grep -oP 'duration=\K[0-9]+' | awk '{s+=$1} END{printf "%d", s}' 2>/dev/null)
    printf "\n${CC}  ┌─ STATYSTYKI: %s ──────────────────────────${C1}\n" "$u"
    printf "  │ Komendy:     %d\n" $total
    [[ $total -gt 0 ]] && printf "  │ Bledy:       %d (%s%%)\n" $fails "$(echo "scale=1;$fails*100/$total" | bc 2>/dev/null || echo 0)"
    printf "  │ Sesje:        %d\n" $sess
    printf "  │ Czas sesji:  ~%dh\n" $(( ${secs:-0}/3600 ))
    printf "  │\n"
    printf "  │ Top 10 komend:\n"
    cat $d/*.log 2>/dev/null | grep '|CMD|' | cut -d'|' -f5 | sort | uniq -c | sort -rn | head -10 | \
      while read cnt cmd; do printf "  │   %5d x  %s\n" "$cnt" "${cmd:0:50}"; done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    printf "  └%s\n\n" "───────────────────────────────────────"
    ;;

  history|hist)
    printf "\n${CC}  ┌─ HISTORIA BASH/ZSH PER UZYTKOWNIK ──────────────${C1}\n"
    for u in root ubuntu aisaTob; do
      local bh_file= zh_file=
      # Okresl sciezki
      case $u in
        root)   bh_file=/root/.bash_history;      zh_file=/root/.zsh_history ;;
        *)      bh_file=/home/$u/.bash_history;    zh_file=/home/$u/.zsh_history ;;
      esac
      [[ ! -f $bh_file ]] && bh_file=
      [[ ! -f $zh_file ]] && zh_file=
      [[ -z $bh_file && -z $zh_file ]] && continue
      local bc=0 zc=0
      [[ -n $bh_file ]] && bc=$(wc -l < $bh_file 2>/dev/null)
      [[ -n $zh_file ]] && zc=$(wc -l < $zh_file 2>/dev/null)
      local tot=$((bc+zc))
      local last=
      [[ -n $zh_file ]] && last=$(tail -1 $zh_file 2>/dev/null | sed 's/^:[0-9]*:[0-9];//' | head -c 60)
      [[ -z $last && -n $bh_file ]] && last=$(tail -1 $bh_file 2>/dev/null | head -c 60)
      printf "  │\n"
      printf "  │ %-12s   %5d wpisow   %s\n" "$u" "$tot" "${last:-brak}"
      [[ -n $bh_file ]] && printf "  │   └ bash_history: %d linii (ostatnia: %s)\n" "$bc" "$(tail -1 $bh_file 2>/dev/null | head -c 40)"
      [[ -n $zh_file ]] && printf "  │   └ zsh_history: %d linii\n" "$zc"
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    printf "  │\n"
    printf "  │ Uzyj: lb search <tekst> aby szukac\n"
    printf "  └%s\n\n" "───────────────────────────────────────────────────"
    ;;

  replay|r)
    local u=${a:-root}; local d=$D/$u
    [[ ! -d $d ]] && { printf "  ${CR}Brak sesji: %s${C1}\n" "$u"; return 1; }
    local sfiles=$(ls -t $d/.session-*.log 2>/dev/null | head -5)
    [[ -z $sfiles ]] && { printf "  ${CR}Brak sesji w %s${C1}\n" "$u"; return 1; }
    printf "\n${CC}  ┌─ REPLAY SESJI: %s ────────────────────────${C1}\n" "$u"
    for sf in $sfiles; do
      local sid=$(basename $sf | sed 's/\.session-//;s/\.log//')
      local first=$(head -1 $sf 2>/dev/null)
      local ts=$(echo $first | cut -d'|' -f1)
      local tty=$(echo $first | grep -oP 'tty=\K[^|]+')
      local cmds=$(grep -c '|CMD|' $sf 2>/dev/null || echo 0)
      local ip=$(echo $first | grep -oP 'IP:\K[^|]+')
      printf "  │\n  │ ▶ %s  %s  %d cmd  tty=%s ip=%s\n" "${ts:0:19}" "$sid" "$cmds" "${tty:--}" "${ip:--}"
      grep '|CMD|' $sf 2>/dev/null | head -3 | awk -F'|' '{printf "  │    ▸ %s\n", $5}'
      [[ $cmds -gt 6 ]] && printf "  │   ... (%d wiecej)\n" $((cmds-6))
      grep '|CMD|' $sf 2>/dev/null | tail -3 | awk -F'|' '{printf "  │    ▸ %s\n", $5}'
    done < <(find $D -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    printf "  │\n  └%s\n\n" "───────────────────────────────────────────────────"
    ;;

  clean|c)
    printf "  Czyszczenie... "
    find $D -name '*.log' -mtime +1 -not -name '*.gz' -exec gzip -f {} + 2>/dev/null
    find $D -name '*.log' -mtime +30 -delete 2>/dev/null
    find $D -name '*.log.gz' -mtime +30 -delete 2>/dev/null
    printf "OK\n"
    ;;

  help|*)
    printf "\n${CC}  ┌─ LOGBOOK ────────────────────────────────────────${C1}\n"
    printf "  │\n"
    printf "  │  lb users          - uzytkownicy z aktywnoscia\n"
    printf "  │  lb tail [N] [user] - ostatnie N komend (20, root)\n"
    printf "  │  lb search <txt> [u]- szukaj w logach\n"
    printf "  │  lb stats [user]   - statystyki\n"
    printf "  │  lb history        - bash_history per user\n"
    printf "  │  lb replay [user]  - odtworz sesje\n"
    printf "  │  lb clean          - kompresuj/usun stare logi\n"
    printf "  │\n"
    printf "  │  Logi: /var/log/kxl/users/USER/DATE.log\n"
    printf "  └%s\n\n" "───────────────────────────────────────────────────"
    ;;
  esac
}

alias logbook='lb'
